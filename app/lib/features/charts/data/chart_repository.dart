import 'package:drift/drift.dart';

import '../../../core/db/database.dart';
import '../../budgets/data/budget_repository.dart' show normalizeMonth;

class CategorySpending {
  const CategorySpending({required this.categoryId, required this.amount});
  final String categoryId;
  final double amount;
}

class MonthlyTotal {
  const MonthlyTotal({
    required this.month,
    required this.income,
    required this.expense,
  });
  final DateTime month;
  final double income;
  final double expense;
}

abstract class ChartReader {
  Stream<List<CategorySpending>> watchCategoryBreakdown(DateTime month);

  /// Income vs. expense totals per month, for the [months] ending in and
  /// including [through]'s month.
  Stream<List<MonthlyTotal>> watchMonthlyTotals({
    required DateTime through,
    required int months,
  });
}

class DriftChartRepository implements ChartReader {
  DriftChartRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<CategorySpending>> watchCategoryBreakdown(DateTime month) {
    final start = normalizeMonth(month);
    final end = DateTime(start.year, start.month + 1, 1);

    final amountSum = _db.transactions.amount.sum();
    final query = _db.selectOnly(_db.transactions)
      ..addColumns([_db.transactions.categoryId, amountSum])
      ..where(_db.transactions.type.equals('expense') &
          _db.transactions.deletedAt.isNull() &
          _db.transactions.occurredAt.isBiggerOrEqualValue(start) &
          _db.transactions.occurredAt.isSmallerThanValue(end))
      ..groupBy([_db.transactions.categoryId]);

    return query.watch().map((rows) => rows
        .map((row) => CategorySpending(
              categoryId: row.read(_db.transactions.categoryId)!,
              amount: row.read(amountSum) ?? 0,
            ))
        .where((c) => c.amount > 0)
        .toList());
  }

  @override
  Stream<List<MonthlyTotal>> watchMonthlyTotals({
    required DateTime through,
    required int months,
  }) {
    final end = normalizeMonth(through);
    final start = DateTime(end.year, end.month - months + 1, 1);

    final query = _db.customSelect(
      '''
      SELECT
        strftime('%Y-%m', occurred_at, 'unixepoch') AS month_key,
        SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END) AS income,
        SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END) AS expense
      FROM transactions
      WHERE deleted_at IS NULL AND occurred_at >= :start
      GROUP BY month_key
      ORDER BY month_key ASC
      ''',
      variables: [Variable.withDateTime(start)],
      readsFrom: {_db.transactions},
    );

    return query.watch().map((rows) {
      final byKey = <String, MonthlyTotal>{};
      for (final row in rows) {
        final key = row.read<String>('month_key');
        final parts = key.split('-');
        byKey[key] = MonthlyTotal(
          month: DateTime(int.parse(parts[0]), int.parse(parts[1]), 1),
          income: row.read<double>('income'),
          expense: row.read<double>('expense'),
        );
      }
      // Fill in months with no transactions at all, so the chart's x-axis
      // is a continuous run rather than skipping empty months.
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
}
