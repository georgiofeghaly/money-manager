import 'package:collection/collection.dart';

import '../../core/db/database.dart';
import '../../features/accounts/data/account_repository.dart';
import 'watch_derived.dart';
import 'web_data_store.dart';

/// Read-only mirror of DriftAccountRepository's queries, computed in memory
/// from the store's full snapshot instead of SQL — see WebDataStore for why
/// there's no local database on web to query against.
class ApiAccountRepository implements AccountReader {
  ApiAccountRepository(this._store);

  final WebDataStore _store;

  List<Account> _active() => _store.accounts
      .where((a) => a.deletedAt == null && a.archivedAt == null)
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  @override
  Stream<List<Account>> watchAccounts() => watchDerived(_store, _active);

  @override
  Stream<List<Account>> watchAllAccountsForLookup() => watchDerived(_store, () {
        final all = [..._store.accounts];
        all.sort((a, b) => a.name.compareTo(b.name));
        return all;
      });

  @override
  Stream<List<Account>> watchArchivedAccounts() => watchDerived(_store, () {
        final archived = _store.accounts
            .where((a) => a.deletedAt == null && a.archivedAt != null)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        return archived;
      });

  @override
  Stream<double> watchBalance(String accountId) => watchDerived(_store, () {
        final account = _store.accounts.firstWhereOrNull((a) => a.id == accountId);
        var balance = account?.startingBalance ?? 0;
        for (final t in _store.transactions) {
          if (t.deletedAt != null) continue;
          if (t.type == 'income' && t.accountId == accountId) {
            balance += t.amount;
          } else if (t.type == 'expense' && t.accountId == accountId) {
            balance -= t.amount;
          } else if (t.type == 'transfer' && t.accountId == accountId) {
            balance -= t.amount;
          } else if (t.type == 'transfer' && t.transferToAccountId == accountId) {
            balance += t.amount;
          }
        }
        return balance;
      });
}
