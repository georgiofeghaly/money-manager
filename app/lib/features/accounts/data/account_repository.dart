import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/database.dart';

const _uuid = Uuid();

/// Read-only surface — the only one the web viewer depends on (see
/// app/lib/web/data/api_account_repository.dart).
abstract class AccountReader {
  Stream<List<Account>> watchAccounts();
  Stream<List<Account>> watchAllAccountsForLookup();
  Stream<List<Account>> watchArchivedAccounts();
  Stream<double> watchBalance(String accountId);
}

/// Mutating surface — mobile-only. The web app never depends on this, so an
/// API-backed reader has no way to accidentally expose a write path.
abstract class AccountWriter {
  Future<String> createAccount({
    required String name,
    required String type,
    double startingBalance = 0,
  });

  Future<void> updateAccount({
    required String id,
    required String name,
    required String type,
    required double startingBalance,
  });

  Future<void> setArchived(String id, bool archived);

  Future<void> deleteAccount(String id);
}

class DriftAccountRepository implements AccountReader, AccountWriter {
  DriftAccountRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Account>> watchAccounts() {
    return (_db.select(_db.accounts)
          ..where((a) => a.deletedAt.isNull() & a.archivedAt.isNull())
          ..orderBy([(a) => OrderingTerm.asc(a.name)]))
        .watch();
  }

  /// Includes archived *and* deleted accounts, so historical transactions
  /// can still resolve a name for an account that's since been archived or
  /// deleted (mirrors CategoryRepository's lookup streams).
  @override
  Stream<List<Account>> watchAllAccountsForLookup() {
    return (_db.select(_db.accounts)
          ..orderBy([(a) => OrderingTerm.asc(a.name)]))
        .watch();
  }

  @override
  Stream<List<Account>> watchArchivedAccounts() {
    return (_db.select(_db.accounts)
          ..where((a) => a.deletedAt.isNull() & a.archivedAt.isNotNull())
          ..orderBy([(a) => OrderingTerm.asc(a.name)]))
        .watch();
  }

  @override
  Future<String> createAccount({
    required String name,
    required String type,
    double startingBalance = 0,
  }) async {
    final id = _uuid.v4();
    await _db.into(_db.accounts).insert(
          AccountsCompanion.insert(
            id: id,
            name: name,
            type: type,
            startingBalance: Value(startingBalance),
            updatedAt: DateTime.now(),
            syncStatus: const Value('pending'),
          ),
        );
    return id;
  }

  @override
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
        syncStatus: const Value('pending'),
      ),
    );
  }

  /// Archived accounts drop out of pickers/the active list but stay
  /// resolvable by name for any transaction that already references them.
  @override
  Future<void> setArchived(String id, bool archived) {
    return (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(
        archivedAt: Value(archived ? DateTime.now() : null),
        updatedAt: Value(DateTime.now()),
        syncStatus: const Value('pending'),
      ),
    );
  }

  /// Soft-delete: existing transactions referencing this account keep
  /// resolving its name (see watchAllAccountsForLookup), it just disappears
  /// from the active list and the archived-accounts list.
  @override
  Future<void> deleteAccount(String id) {
    return (_db.update(_db.accounts)..where((a) => a.id.equals(id))).write(
      AccountsCompanion(
        deletedAt: Value(DateTime.now()),
        syncStatus: const Value('pending'),
      ),
    );
  }

  /// Balance = starting balance + income - expense - outgoing transfers + incoming transfers,
  /// computed live from transactions rather than stored, so it can never drift out of sync.
  @override
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
