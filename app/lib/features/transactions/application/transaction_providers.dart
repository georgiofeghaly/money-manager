import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/database_provider.dart';
import '../data/transaction_repository.dart';

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return TransactionRepository(ref.watch(databaseProvider));
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
