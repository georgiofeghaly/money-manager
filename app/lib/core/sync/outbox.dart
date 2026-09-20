import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/database.dart';
import 'sync_models.dart';

const _uuid = Uuid();

class DirtyRows {
  const DirtyRows({
    required this.accounts,
    required this.categories,
    required this.transactions,
    required this.budgets,
  });

  final List<Account> accounts;
  final List<Category> categories;
  final List<Transaction> transactions;
  final List<Budget> budgets;

  int get total =>
      accounts.length + categories.length + transactions.length + budgets.length;
}

/// Finds locally-dirty rows for [SyncEngine] to push, and applies push/pull
/// results back onto the local database. All the table-specific plumbing
/// sync_engine.dart needs lives here so it can stay focused on
/// orchestration.
class Outbox {
  Outbox(this._db);

  final AppDatabase _db;

  /// Rows with `syncStatus == 'pending'`. Rows marked `'conflict'` are
  /// deliberately excluded — they stay out of the outbox until the user
  /// resolves them (features/sync_conflicts/), at which point resolution
  /// flips them back to `'pending'` with a corrected version.
  Future<DirtyRows> collectDirtyRows() async {
    final accounts = await (_db.select(_db.accounts)
          ..where((a) => a.syncStatus.equals('pending')))
        .get();
    final categories = await (_db.select(_db.categories)
          ..where((c) => c.syncStatus.equals('pending')))
        .get();
    final transactions = await (_db.select(_db.transactions)
          ..where((t) => t.syncStatus.equals('pending')))
        .get();
    final budgets = await (_db.select(_db.budgets)
          ..where((b) => b.syncStatus.equals('pending')))
        .get();
    return DirtyRows(
      accounts: accounts,
      categories: categories,
      transactions: transactions,
      budgets: budgets,
    );
  }

  // ---- mark-synced (after an accepted push) ------------------------------
  //
  // Partial update: the business fields we pushed are already correct
  // locally, only the sync-metadata columns need to reflect what the server
  // recorded.

  Future<void> markAccountSynced(String id,
      {required int version, required DateTime updatedAt, String? originDeviceId}) {
    return (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(
        version: Value(version),
        updatedAt: Value(updatedAt),
        originDeviceId: Value(originDeviceId),
        syncStatus: const Value('synced'),
      ),
    );
  }

  Future<void> markCategorySynced(String id,
      {required int version, required DateTime updatedAt, String? originDeviceId}) {
    return (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        version: Value(version),
        updatedAt: Value(updatedAt),
        originDeviceId: Value(originDeviceId),
        syncStatus: const Value('synced'),
      ),
    );
  }

  Future<void> markTransactionSynced(String id,
      {required int version, required DateTime updatedAt, String? originDeviceId}) {
    return (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        version: Value(version),
        updatedAt: Value(updatedAt),
        originDeviceId: Value(originDeviceId),
        syncStatus: const Value('synced'),
      ),
    );
  }

  Future<void> markBudgetSynced(String id,
      {required int version, required DateTime updatedAt, String? originDeviceId}) {
    return (_db.update(_db.budgets)..where((b) => b.id.equals(id))).write(
      BudgetsCompanion(
        version: Value(version),
        updatedAt: Value(updatedAt),
        originDeviceId: Value(originDeviceId),
        syncStatus: const Value('synced'),
      ),
    );
  }

  // ---- pending lookups (client-side pull-conflict detection) -------------

  Future<Account?> findPendingAccount(String id) {
    return (_db.select(_db.accounts)
          ..where((a) => a.id.equals(id) & a.syncStatus.equals('pending')))
        .getSingleOrNull();
  }

  Future<Category?> findPendingCategory(String id) {
    return (_db.select(_db.categories)
          ..where((c) => c.id.equals(id) & c.syncStatus.equals('pending')))
        .getSingleOrNull();
  }

  Future<Transaction?> findPendingTransaction(String id) {
    return (_db.select(_db.transactions)
          ..where((t) => t.id.equals(id) & t.syncStatus.equals('pending')))
        .getSingleOrNull();
  }

  Future<Budget?> findPendingBudget(String id) {
    return (_db.select(_db.budgets)
          ..where((b) => b.id.equals(id) & b.syncStatus.equals('pending')))
        .getSingleOrNull();
  }

  // ---- full upsert (pull-apply) -------------------------------------------
  //
  // Unlike mark-synced above, a pulled row may be entirely new to this
  // device (another device created it) or an update to every field, so this
  // replaces the whole row keyed by primary key `id`.

  Future<void> upsertAccountFromServer(Map<String, dynamic> json) {
    return _db.into(_db.accounts).insertOnConflictUpdate(
          AccountsCompanion.insert(
            id: json['id'] as String,
            userId: Value(json['userId'] as String),
            name: json['name'] as String,
            type: json['type'] as String,
            startingBalance: Value((json['startingBalance'] as num).toDouble()),
            archivedAt: Value(_parseNullableDate(json['archivedAt'])),
            updatedAt: DateTime.parse(json['updatedAt'] as String),
            version: Value(json['version'] as int),
            originDeviceId: Value(json['originDeviceId'] as String?),
            deletedAt: Value(_parseNullableDate(json['deletedAt'])),
            syncStatus: const Value('synced'),
          ),
        );
  }

  Future<void> upsertCategoryFromServer(Map<String, dynamic> json) {
    return _db.into(_db.categories).insertOnConflictUpdate(
          CategoriesCompanion.insert(
            id: json['id'] as String,
            userId: Value(json['userId'] as String?),
            kind: json['kind'] as String,
            name: json['name'] as String,
            icon: Value(json['icon'] as String?),
            color: Value(json['color'] as int?),
            isSeed: const Value(false), // server never sends seed rows to a client
            updatedAt: DateTime.parse(json['updatedAt'] as String),
            version: Value(json['version'] as int),
            originDeviceId: Value(json['originDeviceId'] as String?),
            deletedAt: Value(_parseNullableDate(json['deletedAt'])),
            syncStatus: const Value('synced'),
          ),
        );
  }

  Future<void> upsertTransactionFromServer(Map<String, dynamic> json) {
    return _db.into(_db.transactions).insertOnConflictUpdate(
          TransactionsCompanion.insert(
            id: json['id'] as String,
            userId: Value(json['userId'] as String),
            type: json['type'] as String,
            amount: (json['amount'] as num).toDouble(),
            occurredAt: DateTime.parse(json['occurredAt'] as String),
            accountId: json['accountId'] as String,
            transferToAccountId: Value(json['transferToAccountId'] as String?),
            categoryId: Value(json['categoryId'] as String?),
            note: Value(json['note'] as String?),
            updatedAt: DateTime.parse(json['updatedAt'] as String),
            version: Value(json['version'] as int),
            originDeviceId: Value(json['originDeviceId'] as String?),
            deletedAt: Value(_parseNullableDate(json['deletedAt'])),
            syncStatus: const Value('synced'),
          ),
        );
  }

  Future<void> upsertBudgetFromServer(Map<String, dynamic> json) {
    return _db.into(_db.budgets).insertOnConflictUpdate(
          BudgetsCompanion.insert(
            id: json['id'] as String,
            userId: Value(json['userId'] as String),
            categoryId: json['categoryId'] as String,
            periodMonth: DateTime.parse(json['periodMonth'] as String),
            limitAmount: (json['limitAmount'] as num).toDouble(),
            updatedAt: DateTime.parse(json['updatedAt'] as String),
            version: Value(json['version'] as int),
            originDeviceId: Value(json['originDeviceId'] as String?),
            deletedAt: Value(_parseNullableDate(json['deletedAt'])),
            syncStatus: const Value('synced'),
          ),
        );
  }

  // ---- conflicts ------------------------------------------------------------

  /// Records a conflict for the resolution UI (features/sync_conflicts/) and
  /// flips the local row's status to `'conflict'` so [collectDirtyRows]
  /// stops re-pushing it until the user resolves it.
  Future<void> writeConflict(
    SyncTableName table,
    String rowId,
    Map<String, dynamic> localJson,
    Map<String, dynamic> serverJson,
  ) async {
    await _db.into(_db.syncConflicts).insert(
          SyncConflictsCompanion.insert(
            id: _uuid.v4(),
            syncTableName: table.name,
            rowId: rowId,
            localRowJson: jsonEncode(localJson),
            serverRowJson: jsonEncode(serverJson),
            detectedAt: DateTime.now(),
          ),
        );

    switch (table) {
      case SyncTableName.accounts:
        await (_db.update(_db.accounts)..where((a) => a.id.equals(rowId)))
            .write(const AccountsCompanion(syncStatus: Value('conflict')));
      case SyncTableName.categories:
        await (_db.update(_db.categories)..where((c) => c.id.equals(rowId)))
            .write(const CategoriesCompanion(syncStatus: Value('conflict')));
      case SyncTableName.transactions:
        await (_db.update(_db.transactions)..where((t) => t.id.equals(rowId)))
            .write(const TransactionsCompanion(syncStatus: Value('conflict')));
      case SyncTableName.budgets:
        await (_db.update(_db.budgets)..where((b) => b.id.equals(rowId)))
            .write(const BudgetsCompanion(syncStatus: Value('conflict')));
    }
  }

  Stream<int> watchOpenConflictCount() {
    final query = _db.selectOnly(_db.syncConflicts)
      ..addColumns([_db.syncConflicts.id.count()])
      ..where(_db.syncConflicts.resolvedAt.isNull());
    return query.watchSingle().map((row) => row.read(_db.syncConflicts.id.count()) ?? 0);
  }

  Stream<List<SyncConflict>> watchOpenConflicts() {
    return (_db.select(_db.syncConflicts)
          ..where((c) => c.resolvedAt.isNull())
          ..orderBy([(c) => OrderingTerm.desc(c.detectedAt)]))
        .watch();
  }

  /// Applies [chosenJson] (either side of a conflict — see
  /// features/sync_conflicts/data/sync_conflict_repository.dart) as the
  /// row's new local field values, adopting [version] as the new baseline
  /// so the next push's `localBaseVersion` matches what the server has.
  /// `syncStatus` goes back to `'pending'` — even when the chosen side is
  /// the server's, this device still needs to push once to confirm it has
  /// converged (cheap, and keeps the state machine uniform).
  Future<void> resolveConflict(
    SyncTableName table,
    String rowId,
    Map<String, dynamic> chosenJson, {
    required int version,
  }) async {
    final now = DateTime.now();
    switch (table) {
      case SyncTableName.accounts:
        await (_db.update(_db.accounts)..where((a) => a.id.equals(rowId))).write(
          AccountsCompanion(
            name: Value(chosenJson['name'] as String),
            type: Value(chosenJson['type'] as String),
            startingBalance: Value((chosenJson['startingBalance'] as num).toDouble()),
            archivedAt: Value(_parseNullableDate(chosenJson['archivedAt'])),
            deletedAt: Value(_parseNullableDate(chosenJson['deletedAt'])),
            version: Value(version),
            updatedAt: Value(now),
            syncStatus: const Value('pending'),
          ),
        );
      case SyncTableName.categories:
        await (_db.update(_db.categories)..where((c) => c.id.equals(rowId))).write(
          CategoriesCompanion(
            name: Value(chosenJson['name'] as String),
            icon: Value(chosenJson['icon'] as String?),
            color: Value(chosenJson['color'] as int?),
            deletedAt: Value(_parseNullableDate(chosenJson['deletedAt'])),
            version: Value(version),
            updatedAt: Value(now),
            syncStatus: const Value('pending'),
          ),
        );
      case SyncTableName.transactions:
        await (_db.update(_db.transactions)..where((t) => t.id.equals(rowId))).write(
          TransactionsCompanion(
            type: Value(chosenJson['type'] as String),
            amount: Value((chosenJson['amount'] as num).toDouble()),
            occurredAt: Value(DateTime.parse(chosenJson['occurredAt'] as String)),
            accountId: Value(chosenJson['accountId'] as String),
            transferToAccountId: Value(chosenJson['transferToAccountId'] as String?),
            categoryId: Value(chosenJson['categoryId'] as String?),
            note: Value(chosenJson['note'] as String?),
            deletedAt: Value(_parseNullableDate(chosenJson['deletedAt'])),
            version: Value(version),
            updatedAt: Value(now),
            syncStatus: const Value('pending'),
          ),
        );
      case SyncTableName.budgets:
        await (_db.update(_db.budgets)..where((b) => b.id.equals(rowId))).write(
          BudgetsCompanion(
            categoryId: Value(chosenJson['categoryId'] as String),
            periodMonth: Value(DateTime.parse(chosenJson['periodMonth'] as String)),
            limitAmount: Value((chosenJson['limitAmount'] as num).toDouble()),
            deletedAt: Value(_parseNullableDate(chosenJson['deletedAt'])),
            version: Value(version),
            updatedAt: Value(now),
            syncStatus: const Value('pending'),
          ),
        );
    }
  }

  Future<void> markConflictResolved(String conflictId) {
    return (_db.update(_db.syncConflicts)..where((c) => c.id.equals(conflictId)))
        .write(SyncConflictsCompanion(resolvedAt: Value(DateTime.now())));
  }
}

DateTime? _parseNullableDate(Object? value) =>
    value == null ? null : DateTime.parse(value as String);
