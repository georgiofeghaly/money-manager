import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/database.dart';

const _uuid = Uuid();

class AccountRepository {
  AccountRepository(this._db);

  final AppDatabase _db;

  Stream<List<Account>> watchAccounts() {
    return (_db.select(_db.accounts)
          ..where((a) => a.deletedAt.isNull() & a.archivedAt.isNull())
          ..orderBy([(a) => OrderingTerm.asc(a.name)]))
        .watch();
  }

  /// Includes archived accounts (but not deleted ones) so historical
  /// transactions can still resolve an archived account's name.
  Stream<List<Account>> watchAllAccountsForLookup() {
    return (_db.select(_db.accounts)
          ..where((a) => a.deletedAt.isNull())
          ..orderBy([(a) => OrderingTerm.asc(a.name)]))
        .watch();
  }

  Future<void> createAccount({
    required String name,
    required String type,
    double startingBalance = 0,
  }) {
    final now = DateTime.now();
    return _db.into(_db.accounts).insert(
          AccountsCompanion.insert(
            id: _uuid.v4(),
            name: name,
            type: type,
            startingBalance: Value(startingBalance),
            updatedAt: now,
          ),
        );
  }

  Future<void> updateAccount({
    required String id,
    required String name,
    required String type,
    required double startingBalance,
  }) {
    return (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(
        name: Value(name),
        type: Value(type),
        startingBalance: Value(startingBalance),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Archived accounts drop out of pickers/the active list but stay
  /// resolvable by name for any transaction that already references them.
  Future<void> setArchived(String id, bool archived) {
    return (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(
        archivedAt: Value(archived ? DateTime.now() : null),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Balance = starting balance + income - expense - outgoing transfers + incoming transfers,
  /// computed live from transactions rather than stored, so it can never drift out of sync.
  Stream<double> watchBalance(String accountId) {
    final query = _db.customSelect(
      '''
      SELECT
        (SELECT starting_balance FROM accounts WHERE id = :id) +
        COALESCE((SELECT SUM(amount) FROM transactions WHERE account_id = :id AND type = 'income' AND deleted_at IS NULL), 0) -
        COALESCE((SELECT SUM(amount) FROM transactions WHERE account_id = :id AND type = 'expense' AND deleted_at IS NULL), 0) -
        COALESCE((SELECT SUM(amount) FROM transactions WHERE account_id = :id AND type = 'transfer' AND deleted_at IS NULL), 0) +
        COALESCE((SELECT SUM(amount) FROM transactions WHERE transfer_to_account_id = :id AND type = 'transfer' AND deleted_at IS NULL), 0)
        AS balance
      ''',
      variables: [Variable.withString(accountId)],
      readsFrom: {_db.accounts, _db.transactions},
    );
    return query.watchSingle().map((row) => row.read<double>('balance'));
  }
}
