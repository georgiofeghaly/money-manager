import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../data/chart_repository.dart';

final chartRepositoryProvider = Provider<ChartRepository>((ref) {
  return ChartRepository(ref.watch(databaseProvider));
});

final categoryBreakdownProvider =
    StreamProvider.family<List<CategorySpending>, DateTime>((ref, month) {
  return ref.watch(chartRepositoryProvider).watchCategoryBreakdown(month);
});

class MonthlyTotalsKey {
  const MonthlyTotalsKey(this.through, this.months);
  final DateTime through;
  final int months;

  @override
  bool operator ==(Object other) =>
      other is MonthlyTotalsKey &&
      other.through == through &&
      other.months == months;

  @override
  int get hashCode => Object.hash(through, months);
}

final monthlyTotalsProvider =
    StreamProvider.family<List<MonthlyTotal>, MonthlyTotalsKey>((ref, key) {
  return ref
      .watch(chartRepositoryProvider)
      .watchMonthlyTotals(through: key.through, months: key.months);
});
