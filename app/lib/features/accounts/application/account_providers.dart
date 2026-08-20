import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/database_provider.dart';
import '../data/account_repository.dart';

final accountRepositoryProvider = Provider<AccountRepository>((ref) {
  return AccountRepository(ref.watch(databaseProvider));
});

final accountsProvider = StreamProvider<List<Account>>((ref) {
  return ref.watch(accountRepositoryProvider).watchAccounts();
});

/// Includes archived accounts, so a transaction form editing an old entry
/// can still resolve/display an account that's since been archived.
final accountsForLookupProvider = StreamProvider<List<Account>>((ref) {
  return ref.watch(accountRepositoryProvider).watchAllAccountsForLookup();
});

final accountBalanceProvider =
    StreamProvider.family<double, String>((ref, accountId) {
  return ref.watch(accountRepositoryProvider).watchBalance(accountId);
});
