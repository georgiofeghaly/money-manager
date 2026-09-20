import '../db/database.dart';
import 'api_client.dart';
import 'connection_settings.dart';
import 'outbox.dart';
import 'sync_models.dart';

typedef ProgressCallback = void Function(SyncProgress progress);

/// One sync pass: push local changes, then pull remote changes until
/// caught up. Push-then-pull (not the reverse) so a row this device just
/// edited doesn't get momentarily overwritten by a stale pull result from
/// before the push landed.
class SyncEngine {
  SyncEngine(AppDatabase db, this._api, this._settings) : _outbox = Outbox(db);

  final ApiClient _api;
  final ConnectionSettings _settings;
  final Outbox _outbox;

  Future<void> runSync({ProgressCallback? onProgress}) async {
    final deviceId = await _settings.ensureDeviceId();
    onProgress?.call(const SyncProgress(phase: SyncPhase.syncing));

    try {
      await _push(deviceId, onProgress);
      await _pull(onProgress);

      final now = DateTime.now();
      await _settings.writeLastSyncedAt(now);
      await _settings.writeLastSyncStatus('ok');
      onProgress?.call(SyncProgress(phase: SyncPhase.idle, lastSyncedAt: now));
    } on ApiException catch (e) {
      await _settings.writeLastSyncStatus('error');
      onProgress?.call(SyncProgress(phase: SyncPhase.error, lastError: e.message));
      rethrow;
    }
  }

  // ---- push -----------------------------------------------------------------

  Future<void> _push(String deviceId, ProgressCallback? onProgress) async {
    final dirty = await _outbox.collectDirtyRows();
    if (dirty.total == 0) return;

    var done = 0;
    void tick() => onProgress?.call(
          SyncProgress(phase: SyncPhase.syncing, current: ++done, total: dirty.total),
        );
    onProgress?.call(SyncProgress(phase: SyncPhase.syncing, current: 0, total: dirty.total));

    final response = await _api.pushSync(
      deviceId: deviceId,
      tables: {
        'accounts': [for (final row in dirty.accounts) _accountToPushJson(row)],
        'categories': [for (final row in dirty.categories) _categoryToPushJson(row)],
        'transactions': [for (final row in dirty.transactions) _transactionToPushJson(row)],
        'budgets': [for (final row in dirty.budgets) _budgetToPushJson(row)],
      },
    );

    final accepted = response['accepted'] as Map<String, dynamic>;
    final conflicts = response['conflicts'] as Map<String, dynamic>;

    for (final json in _list(accepted['accounts'])) {
      await _outbox.markAccountSynced(
        json['id'] as String,
        version: json['version'] as int,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        originDeviceId: json['originDeviceId'] as String?,
      );
      tick();
    }
    for (final json in _list(accepted['categories'])) {
      await _outbox.markCategorySynced(
        json['id'] as String,
        version: json['version'] as int,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        originDeviceId: json['originDeviceId'] as String?,
      );
      tick();
    }
    for (final json in _list(accepted['transactions'])) {
      await _outbox.markTransactionSynced(
        json['id'] as String,
        version: json['version'] as int,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        originDeviceId: json['originDeviceId'] as String?,
      );
      tick();
    }
    for (final json in _list(accepted['budgets'])) {
      await _outbox.markBudgetSynced(
        json['id'] as String,
        version: json['version'] as int,
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        originDeviceId: json['originDeviceId'] as String?,
      );
      tick();
    }

    for (final json in _list(conflicts['accounts'])) {
      final local = dirty.accounts.firstWhere((r) => r.id == json['id']);
      await _outbox.writeConflict(
          SyncTableName.accounts, local.id, _accountToFullJson(local), json);
      tick();
    }
    for (final json in _list(conflicts['categories'])) {
      final local = dirty.categories.firstWhere((r) => r.id == json['id']);
      await _outbox.writeConflict(
          SyncTableName.categories, local.id, _categoryToFullJson(local), json);
      tick();
    }
    for (final json in _list(conflicts['transactions'])) {
      final local = dirty.transactions.firstWhere((r) => r.id == json['id']);
      await _outbox.writeConflict(
          SyncTableName.transactions, local.id, _transactionToFullJson(local), json);
      tick();
    }
    for (final json in _list(conflicts['budgets'])) {
      final local = dirty.budgets.firstWhere((r) => r.id == json['id']);
      await _outbox.writeConflict(
          SyncTableName.budgets, local.id, _budgetToFullJson(local), json);
      tick();
    }
  }

  // ---- pull -----------------------------------------------------------------

  Future<void> _pull(ProgressCallback? onProgress) async {
    String since = await _settings.readPullCursorSince();
    String cursorId = await _settings.readPullCursorId();

    while (true) {
      final response = await _api.pullSync(since: since, cursorId: cursorId);
      final tables = response['tables'] as Map<String, dynamic>;

      final accounts = _list(tables['accounts']);
      final categories = _list(tables['categories']);
      final transactions = _list(tables['transactions']);
      final budgets = _list(tables['budgets']);

      final total =
          accounts.length + categories.length + transactions.length + budgets.length;
      var done = 0;
      void tick() => onProgress?.call(
            SyncProgress(phase: SyncPhase.syncing, current: ++done, total: total),
          );
      if (total > 0) {
        onProgress?.call(SyncProgress(phase: SyncPhase.syncing, current: 0, total: total));
      }

      // FK-safe order: accounts/categories before transactions before
      // budgets — same order the backend writes in.
      for (final json in accounts) {
        await _applyPulledAccount(json);
        tick();
      }
      for (final json in categories) {
        await _applyPulledCategory(json);
        tick();
      }
      for (final json in transactions) {
        await _applyPulledTransaction(json);
        tick();
      }
      for (final json in budgets) {
        await _applyPulledBudget(json);
        tick();
      }

      final nextCursor = response['nextCursor'] as Map<String, dynamic>?;
      if (nextCursor == null) {
        // No more pages: advance the cursor to the server's own clock so it
        // still moves forward even on a pull that returned zero rows.
        since = response['serverTime'] as String;
        cursorId = '';
        break;
      }
      since = nextCursor['since'] as String;
      cursorId = nextCursor['cursorId'] as String;
    }

    await _settings.writePullCursor(since: since, cursorId: cursorId);
  }

  Future<void> _applyPulledAccount(Map<String, dynamic> json) async {
    final pending = await _outbox.findPendingAccount(json['id'] as String);
    if (pending != null && pending.version != json['version']) {
      await _outbox.writeConflict(
          SyncTableName.accounts, pending.id, _accountToFullJson(pending), json);
      return;
    }
    await _outbox.upsertAccountFromServer(json);
  }

  Future<void> _applyPulledCategory(Map<String, dynamic> json) async {
    final pending = await _outbox.findPendingCategory(json['id'] as String);
    if (pending != null && pending.version != json['version']) {
      await _outbox.writeConflict(
          SyncTableName.categories, pending.id, _categoryToFullJson(pending), json);
      return;
    }
    await _outbox.upsertCategoryFromServer(json);
  }

  Future<void> _applyPulledTransaction(Map<String, dynamic> json) async {
    final pending = await _outbox.findPendingTransaction(json['id'] as String);
    if (pending != null && pending.version != json['version']) {
      await _outbox.writeConflict(
          SyncTableName.transactions, pending.id, _transactionToFullJson(pending), json);
      return;
    }
    await _outbox.upsertTransactionFromServer(json);
  }

  Future<void> _applyPulledBudget(Map<String, dynamic> json) async {
    final pending = await _outbox.findPendingBudget(json['id'] as String);
    if (pending != null && pending.version != json['version']) {
      await _outbox.writeConflict(
          SyncTableName.budgets, pending.id, _budgetToFullJson(pending), json);
      return;
    }
    await _outbox.upsertBudgetFromServer(json);
  }
}

List<Map<String, dynamic>> _list(Object? value) =>
    (value as List? ?? const []).cast<Map<String, dynamic>>();

/// The server `version` this device last saw, or `null` for a row it
/// believes doesn't exist on the server yet. `originDeviceId` is only ever
/// set by the sync engine itself (repositories never touch it), so a null
/// value reliably means "created locally, never synced" — distinct from a
/// freshly-synced row that also happens to have `version == 1`.
int? _localBaseVersion({required String? originDeviceId, required int version}) =>
    originDeviceId == null ? null : version;

Map<String, dynamic> _accountToPushJson(Account row) => {
      'id': row.id,
      'localBaseVersion':
          _localBaseVersion(originDeviceId: row.originDeviceId, version: row.version),
      'name': row.name,
      'type': row.type,
      'startingBalance': row.startingBalance,
      'archivedAt': row.archivedAt?.toUtc().toIso8601String(),
      'deletedAt': row.deletedAt?.toUtc().toIso8601String(),
    };

Map<String, dynamic> _categoryToPushJson(Category row) => {
      'id': row.id,
      'localBaseVersion':
          _localBaseVersion(originDeviceId: row.originDeviceId, version: row.version),
      'kind': row.kind,
      'name': row.name,
      'icon': row.icon,
      'color': row.color,
      'deletedAt': row.deletedAt?.toUtc().toIso8601String(),
    };

Map<String, dynamic> _transactionToPushJson(Transaction row) => {
      'id': row.id,
      'localBaseVersion':
          _localBaseVersion(originDeviceId: row.originDeviceId, version: row.version),
      'type': row.type,
      'amount': row.amount,
      'occurredAt': row.occurredAt.toUtc().toIso8601String(),
      'accountId': row.accountId,
      'transferToAccountId': row.transferToAccountId,
      'categoryId': row.categoryId,
      'note': row.note,
      'deletedAt': row.deletedAt?.toUtc().toIso8601String(),
    };

Map<String, dynamic> _budgetToPushJson(Budget row) => {
      'id': row.id,
      'localBaseVersion':
          _localBaseVersion(originDeviceId: row.originDeviceId, version: row.version),
      'categoryId': row.categoryId,
      'periodMonth': row.periodMonth.toUtc().toIso8601String(),
      'limitAmount': row.limitAmount,
      'deletedAt': row.deletedAt?.toUtc().toIso8601String(),
    };

// ---- "full" (server-row-shaped) JSON, for conflict records --------------
//
// Unlike the push shape above (which sends `localBaseVersion`, no
// `userId`/`version`/`originDeviceId`), a conflict record's local and
// server sides must be structurally identical so features/sync_conflicts/
// can display a clean diff and resolve by writing either side back with
// `version` taken from the server row — this mirrors exactly what the
// backend's accepted/conflict rows already look like (see
// backend/src/modules/sync/sync.routes.ts).

Map<String, dynamic> _accountToFullJson(Account row) => {
      'id': row.id,
      'userId': row.userId,
      'name': row.name,
      'type': row.type,
      'startingBalance': row.startingBalance,
      'archivedAt': row.archivedAt?.toUtc().toIso8601String(),
      'updatedAt': row.updatedAt.toUtc().toIso8601String(),
      'version': row.version,
      'originDeviceId': row.originDeviceId,
      'deletedAt': row.deletedAt?.toUtc().toIso8601String(),
    };

Map<String, dynamic> _categoryToFullJson(Category row) => {
      'id': row.id,
      'userId': row.userId,
      'kind': row.kind,
      'name': row.name,
      'icon': row.icon,
      'color': row.color,
      'updatedAt': row.updatedAt.toUtc().toIso8601String(),
      'version': row.version,
      'originDeviceId': row.originDeviceId,
      'deletedAt': row.deletedAt?.toUtc().toIso8601String(),
    };

Map<String, dynamic> _transactionToFullJson(Transaction row) => {
      'id': row.id,
      'userId': row.userId,
      'type': row.type,
      'amount': row.amount,
      'occurredAt': row.occurredAt.toUtc().toIso8601String(),
      'accountId': row.accountId,
      'transferToAccountId': row.transferToAccountId,
      'categoryId': row.categoryId,
      'note': row.note,
      'updatedAt': row.updatedAt.toUtc().toIso8601String(),
      'version': row.version,
      'originDeviceId': row.originDeviceId,
      'deletedAt': row.deletedAt?.toUtc().toIso8601String(),
    };

Map<String, dynamic> _budgetToFullJson(Budget row) => {
      'id': row.id,
      'userId': row.userId,
      'categoryId': row.categoryId,
      'periodMonth': row.periodMonth.toUtc().toIso8601String(),
      'limitAmount': row.limitAmount,
      'updatedAt': row.updatedAt.toUtc().toIso8601String(),
      'version': row.version,
      'originDeviceId': row.originDeviceId,
      'deletedAt': row.deletedAt?.toUtc().toIso8601String(),
    };
