import '../../../core/db/database.dart';
import 'backup_payload.dart';

class BackupRepository {
  BackupRepository(this._db);

  final AppDatabase _db;

  /// Every row of every table — including archived accounts and
  /// soft-deleted rows — so a restore is byte-faithful, not just a
  /// snapshot of what's currently visible in the UI.
  Future<BackupPayload> exportAll() async {
    final accounts = await _db.select(_db.accounts).get();
    final categories = await _db.select(_db.categories).get();
    final transactions = await _db.select(_db.transactions).get();
    final budgets = await _db.select(_db.budgets).get();

    return BackupPayload(
      formatVersion: kBackupFormatVersion,
      schemaVersion: _db.schemaVersion,
      exportedAt: DateTime.now(),
      accounts: [for (final a in accounts) a.toJson()],
      categories: [for (final c in categories) c.toJson()],
      transactions: [for (final t in transactions) t.toJson()],
      budgets: [for (final b in budgets) b.toJson()],
    );
  }

  /// Replaces ALL current data with [payload], atomically — either every
  /// table ends up replaced, or (on any failure) nothing changes.
  Future<void> restoreAll(BackupPayload payload) {
    return _db.transaction(() async {
      // Children before parents, to satisfy foreign keys during delete.
      await _db.delete(_db.transactions).go();
      await _db.delete(_db.budgets).go();
      await _db.delete(_db.categories).go();
      await _db.delete(_db.accounts).go();

      // Parents before children, to satisfy foreign keys during insert.
      // `toCompanion(false)` (nullToAbsent: false) writes explicit NULLs
      // instead of falling back to column defaults, so soft-deleted /
      // archived state in the backup survives the restore intact.
      await _db.batch((b) => b.insertAll(
            _db.accounts,
            [for (final json in payload.accounts) Account.fromJson(json).toCompanion(false)],
          ));
      await _db.batch((b) => b.insertAll(
            _db.categories,
            [
              for (final json in payload.categories)
                Category.fromJson(json).toCompanion(false),
            ],
          ));
      await _db.batch((b) => b.insertAll(
            _db.transactions,
            [
              for (final json in payload.transactions)
                Transaction.fromJson(json).toCompanion(false),
            ],
          ));
      await _db.batch((b) => b.insertAll(
            _db.budgets,
            [for (final json in payload.budgets) Budget.fromJson(json).toCompanion(false)],
          ));
    });
  }
}
