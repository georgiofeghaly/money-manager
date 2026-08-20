import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/database_provider.dart';
import '../data/budget_repository.dart';

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return BudgetRepository(ref.watch(databaseProvider));
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
