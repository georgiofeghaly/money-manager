import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database_provider.dart';
import '../../../web/data/api_chart_repository.dart';
import '../../../web/data/web_data_providers.dart';
import '../data/chart_repository.dart';

final chartRepositoryProvider = Provider<ChartReader>((ref) {
  if (kIsWeb) return ApiChartRepository(ref.watch(webDataStoreProvider));
  return DriftChartRepository(ref.watch(databaseProvider));
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
