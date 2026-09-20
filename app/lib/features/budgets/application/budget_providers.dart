import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/database_provider.dart';
import '../../../web/data/api_budget_repository.dart';
import '../../../web/data/web_data_providers.dart';
import '../data/budget_repository.dart';

final budgetRepositoryProvider = Provider<BudgetReader>((ref) {
  if (kIsWeb) return ApiBudgetRepository(ref.watch(webDataStoreProvider));
  return DriftBudgetRepository(ref.watch(databaseProvider));
});

final budgetWriterProvider = Provider<BudgetWriter>((ref) {
  final reader = ref.watch(budgetRepositoryProvider);
  if (reader is BudgetWriter) return reader as BudgetWriter;
  throw UnsupportedError('Budget writes are not available on this platform.');
});

final budgetsForMonthProvider =
    StreamProvider.family<List<Budget>, DateTime>((ref, month) {
  return ref.watch(budgetRepositoryProvider).watchBudgetsForMonth(month);
});

class BudgetSpentKey {
  const BudgetSpentKey(this.categoryId, this.month);
  final String categoryId;
  final DateTime month;

  @override
  bool operator ==(Object other) =>
      other is BudgetSpentKey &&
      other.categoryId == categoryId &&
      other.month == month;

  @override
  int get hashCode => Object.hash(categoryId, month);
}

final budgetSpentProvider =
    StreamProvider.family<double, BudgetSpentKey>((ref, key) {
  return ref
      .watch(budgetRepositoryProvider)
      .watchSpent(key.categoryId, key.month);
});
