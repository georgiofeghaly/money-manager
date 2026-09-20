import '../../features/budgets/data/budget_repository.dart' show normalizeMonth;
import '../../features/charts/data/chart_repository.dart';
import 'watch_derived.dart';
import 'web_data_store.dart';

class ApiChartRepository implements ChartReader {
  ApiChartRepository(this._store);

  final WebDataStore _store;

  @override
  Stream<List<CategorySpending>> watchCategoryBreakdown(DateTime month) =>
      watchDerived(_store, () {
        final start = normalizeMonth(month);
        final end = DateTime(start.year, start.month + 1, 1);
        final byCategory = <String, double>{};
        for (final t in _store.transactions) {
          if (t.deletedAt != null) continue;
          if (t.type != 'expense') continue;
          if (t.occurredAt.isBefore(start) || !t.occurredAt.isBefore(end)) continue;
          final key = t.categoryId ?? '';
          byCategory[key] = (byCategory[key] ?? 0) + t.amount;
        }
        return [
          for (final entry in byCategory.entries)
            if (entry.value > 0) CategorySpending(categoryId: entry.key, amount: entry.value),
        ];
      });

  /// Mirrors the Drift version's `strftime(..., 'unixepoch')` grouping,
  /// which buckets by UTC calendar month, not the device's local month.
  @override
  Stream<List<MonthlyTotal>> watchMonthlyTotals({
    required DateTime through,
    required int months,
  }) =>
      watchDerived(_store, () {
        final end = normalizeMonth(through);
        final start = DateTime(end.year, end.month - months + 1, 1);

        final byKey = <String, MonthlyTotal>{};
        for (final t in _store.transactions) {
          if (t.deletedAt != null) continue;
          if (t.occurredAt.isBefore(start)) continue;
          final utc = t.occurredAt.toUtc();
          final key =
              '${utc.year.toString().padLeft(4, '0')}-${utc.month.toString().padLeft(2, '0')}';
          final existing = byKey[key] ?? MonthlyTotal(month: DateTime(utc.year, utc.month, 1), income: 0, expense: 0);
          byKey[key] = MonthlyTotal(
            month: existing.month,
            income: existing.income + (t.type == 'income' ? t.amount : 0),
            expense: existing.expense + (t.type == 'expense' ? t.amount : 0),
          );
        }

        return [
          for (var i = 0; i < months; i++)
            () {
              final m = DateTime(start.year, start.month + i, 1);
              final key =
                  '${m.year.toString().padLeft(4, '0')}-${m.month.toString().padLeft(2, '0')}';
              return byKey[key] ?? MonthlyTotal(month: m, income: 0, expense: 0);
            }(),
        ];
      });
}
