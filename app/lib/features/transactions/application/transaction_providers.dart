import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/database_provider.dart';
import '../../../web/data/api_transaction_repository.dart';
import '../../../web/data/web_data_providers.dart';
import '../../accounts/application/account_providers.dart';
import '../../categories/application/category_providers.dart';
import '../data/transaction_filter.dart';
import '../data/transaction_repository.dart';
import '../data/transaction_search.dart';

final transactionRepositoryProvider = Provider<TransactionReader>((ref) {
  if (kIsWeb) return ApiTransactionRepository(ref.watch(webDataStoreProvider));
  return DriftTransactionRepository(ref.watch(databaseProvider));
});

final transactionWriterProvider = Provider<TransactionWriter>((ref) {
  final reader = ref.watch(transactionRepositoryProvider);
  if (reader is TransactionWriter) return reader as TransactionWriter;
  throw UnsupportedError('Transaction writes are not available on this platform.');
});

class DateRange {
  const DateRange(this.start, this.end);
  final DateTime start;
  final DateTime end;

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

final transactionsInRangeProvider =
    StreamProvider.family<List<Transaction>, DateRange>((ref, range) {
  return ref
      .watch(transactionRepositoryProvider)
      .watchTransactionsInRange(range.start, range.end);
});

final transactionsFilteredProvider =
    StreamProvider.family<List<Transaction>, TransactionFilter>((ref, filter) {
  return ref.watch(transactionRepositoryProvider).watchTransactionsFiltered(filter);
});

/// What the search screen watches: SQL-filtered rows further narrowed by
/// [filter.text] against note/account-name/category-name client-side.
final transactionSearchResultsProvider =
    StreamProvider.family<List<Transaction>, TransactionFilter>((ref, filter) {
  final accounts = ref.watch(accountsForLookupProvider).valueOrNull ?? const [];
  final categories = ref.watch(categoriesAllForLookupProvider).valueOrNull ?? const [];
  return ref
      .watch(transactionRepositoryProvider)
      .watchTransactionsFiltered(filter)
      .map((rows) => applyTextSearch(rows, filter.text, accounts, categories));
});
