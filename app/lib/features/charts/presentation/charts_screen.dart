import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/category_style.dart';
import '../../budgets/data/budget_repository.dart' show normalizeMonth;
import '../../categories/application/category_providers.dart';
import '../application/chart_providers.dart';

const _monthsBack = 6;

class ChartsScreen extends ConsumerStatefulWidget {
  const ChartsScreen({super.key});

  @override
  ConsumerState<ChartsScreen> createState() => _ChartsScreenState();
}

class _ChartsScreenState extends ConsumerState<ChartsScreen> {
  DateTime _month = normalizeMonth(DateTime.now());

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Charts')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Spending by category', style: Theme.of(context).textTheme.titleMedium),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _shiftMonth(-1),
              ),
              Text(DateFormat.yMMMM().format(_month)),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _shiftMonth(1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const _CategoryPie(),
          const SizedBox(height: 32),
          Text('Last $_monthsBack months', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          const _MonthlyBarChart(),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _CategoryPie extends ConsumerWidget {
  const _CategoryPie();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = context.findAncestorStateOfType<_ChartsScreenState>()!._month;
    final breakdownAsync = ref.watch(categoryBreakdownProvider(month));
    final categoriesAsync = ref.watch(categoriesAllForLookupProvider);

    return breakdownAsync.when(
      loading: () => const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, st) => Text('Error: $err'),
      data: (breakdown) {
        if (breakdown.isEmpty) {
          return const SizedBox(
            height: 220,
            child: Center(child: Text('No expenses this month.')),
          );
        }
        final categories = categoriesAsync.valueOrNull ?? const <Category>[];
        final total = breakdown.fold<double>(0, (sum, c) => sum + c.amount);
        final sorted = breakdown.sortedBy<num>((c) => -c.amount);

        return Column(
          children: [
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 48,
                  sections: [
                    for (final entry in sorted)
                      PieChartSectionData(
                        value: entry.amount,
                        color: colorFromArgb(
                          categories
                              .firstWhereOrNull((c) => c.id == entry.categoryId)
                              ?.color,
                          entry.categoryId,
                        ),
                        title: '${(entry.amount / total * 100).round()}%',
                        radius: 56,
                        titleStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            ...sorted.map((entry) {
              final category =
                  categories.firstWhereOrNull((c) => c.id == entry.categoryId);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 6,
                      backgroundColor:
                          colorFromArgb(category?.color, entry.categoryId),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(category?.name ?? 'Uncategorized')),
                    Text(entry.amount.toStringAsFixed(2)),
                  ],
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _MonthlyBarChart extends ConsumerWidget {
  const _MonthlyBarChart();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = MonthlyTotalsKey(normalizeMonth(DateTime.now()), _monthsBack);
    final totalsAsync = ref.watch(monthlyTotalsProvider(key));

    return totalsAsync.when(
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (err, st) => Text('Error: $err'),
      data: (totals) {
        final maxY = totals
            .expand((t) => [t.income, t.expense])
            .fold<double>(0, (max, v) => v > max ? v : max);

        return SizedBox(
          height: 220,
          child: BarChart(
            BarChartData(
              maxY: maxY == 0 ? 1 : maxY * 1.2,
              alignment: BarChartAlignment.spaceAround,
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= totals.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          DateFormat.MMM().format(totals[index].month),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
              barGroups: [
                for (var i = 0; i < totals.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: totals[i].income,
                        color: TransactionColors.income,
                        width: 8,
                      ),
                      BarChartRodData(
                        toY: totals[i].expense,
                        color: TransactionColors.expense(context),
                        width: 8,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
