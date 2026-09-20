import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/database_provider.dart';
import '../../../web/data/api_account_repository.dart';
import '../../../web/data/web_data_providers.dart';
import '../data/account_repository.dart';

final accountRepositoryProvider = Provider<AccountReader>((ref) {
  if (kIsWeb) return ApiAccountRepository(ref.watch(webDataStoreProvider));
  return DriftAccountRepository(ref.watch(databaseProvider));
});

/// Mutations — mobile-only. Never called on web, since the web UI has no
/// create/edit affordances, but throws clearly if it ever is.
final accountWriterProvider = Provider<AccountWriter>((ref) {
  final reader = ref.watch(accountRepositoryProvider);
  if (reader is AccountWriter) return reader as AccountWriter;
  throw UnsupportedError('Account writes are not available on this platform.');
});

final accountsProvider = StreamProvider<List<Account>>((ref) {
  return ref.watch(accountRepositoryProvider).watchAccounts();
});

/// Includes archived accounts, so a transaction form editing an old entry
/// can still resolve/display an account that's since been archived.
final accountsForLookupProvider = StreamProvider<List<Account>>((ref) {
  return ref.watch(accountRepositoryProvider).watchAllAccountsForLookup();
});

final archivedAccountsProvider = StreamProvider<List<Account>>((ref) {
  return ref.watch(accountRepositoryProvider).watchArchivedAccounts();
});

final accountBalanceProvider =
    StreamProvider.family<double, String>((ref, accountId) {
  return ref.watch(accountRepositoryProvider).watchBalance(accountId);
});
