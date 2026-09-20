import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/database.dart';
import '../../../core/theme/app_theme.dart';
import '../../accounts/application/account_providers.dart';
import '../../categories/application/category_providers.dart';
import '../../transactions/application/transaction_providers.dart';
import '../../transactions/presentation/transaction_search_screen.dart';
import '../../transactions/presentation/transaction_tile.dart';

enum _Granularity { day, week, month }

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key, this.readOnly = false});

  /// True on the web viewer — hides search/edit affordances that assume
  /// mutation is possible.
  final bool readOnly;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen>
    with SingleTickerProviderStateMixin {
  DateTime _anchor = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  _Granularity _granularity = _Granularity.month;
  late final TabController _tabController = TabController(length: 3, vsync: this)
    ..addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() => _granularity = _Granularity.values[_tabController.index]);
    });

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  DateTime _startOfWeek(DateTime d) =>
      DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

  DateRange get _range {
    switch (_granularity) {
      case _Granularity.day:
        final start = DateTime(_anchor.year, _anchor.month, _anchor.day);
        return DateRange(start, start.add(const Duration(days: 1)));
      case _Granularity.week:
        final start = _startOfWeek(_anchor);
        return DateRange(start, start.add(const Duration(days: 7)));
      case _Granularity.month:
        final start = DateTime(_anchor.year, _anchor.month, 1);
        final end = DateTime(_anchor.year, _anchor.month + 1, 1);
        return DateRange(start, end);
    }
  }

  String get _periodLabel {
    switch (_granularity) {
      case _Granularity.day:
        return DateFormat.yMMMEd().format(_anchor);
      case _Granularity.week:
        final start = _startOfWeek(_anchor);
        final end = start.add(const Duration(days: 6));
        if (start.month == end.month) {
          return '${DateFormat.MMMd().format(start)} – ${DateFormat.d().format(end)}, ${end.year}';
        }
        return '${DateFormat.MMMd().format(start)} – ${DateFormat.yMMMd().format(end)}';
      case _Granularity.month:
        return DateFormat.yMMMM().format(_anchor);
    }
  }

  void _shiftPeriod(int delta) {
    setState(() {
      switch (_granularity) {
        case _Granularity.day:
          _anchor = _anchor.add(Duration(days: delta));
        case _Granularity.week:
          _anchor = _anchor.add(Duration(days: 7 * delta));
        case _Granularity.month:
          _anchor = DateTime(_anchor.year, _anchor.month + delta, 1);
      }
    });
  }

  Future<void> _jumpToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _anchor,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _anchor = picked);
  }

  @override
  Widget build(BuildContext context) {
    final transactionsAsync = ref.watch(transactionsInRangeProvider(_range));
    final accountsAsync = ref.watch(accountsForLookupProvider);
    final categoriesAsync = ref.watch(categoriesAllForLookupProvider);

    const tightIconConstraints = BoxConstraints(minWidth: 36, minHeight: 36);
    const tightIconPadding = EdgeInsets.zero;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              constraints: tightIconConstraints,
              padding: tightIconPadding,
              onPressed: () => _shiftPeriod(-1),
            ),
            Text(_periodLabel, style: Theme.of(context).textTheme.titleMedium),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              constraints: tightIconConstraints,
              padding: tightIconPadding,
              onPressed: () => _shiftPeriod(1),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search transactions',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TransactionSearchScreen(readOnly: widget.readOnly),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: 'Jump to date',
            onPressed: _jumpToDate,
          ),
        ],
      ),
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            labelPadding: const EdgeInsets.symmetric(vertical: 4),
            tabs: const [
              Tab(height: 36, text: 'Day'),
              Tab(height: 36, text: 'Week'),
              Tab(height: 36, text: 'Month'),
            ],
          ),
          transactionsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (err, st) => const SizedBox.shrink(),
            data: (transactions) => _SummaryBar(transactions: transactions),
          ),
          const Divider(height: 1),
          Expanded(
            child: transactionsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => Center(child: Text('Error: $err')),
              data: (transactions) {
                if (transactions.isEmpty) {
                  return const Center(child: Text('No transactions.'));
                }
                final accounts = accountsAsync.valueOrNull ?? const [];
                final categories = categoriesAsync.valueOrNull ?? const [];
                final grouped = groupBy<Transaction, DateTime>(
                  transactions,
                  (t) => DateTime(
                    t.occurredAt.year,
                    t.occurredAt.month,
                    t.occurredAt.day,
                  ),
                );
                final days = grouped.keys.toList()
                  ..sort((a, b) => b.compareTo(a));

                return ListView.builder(
                  itemCount: days.length,
                  itemBuilder: (context, index) {
                    final day = days[index];
                    final dayTransactions = grouped[day]!;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Text(
                            DateFormat.yMMMEd().format(day),
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary,
                                ),
                          ),
                        ),
                        ...dayTransactions.map(
                          (t) => TransactionTile(
                            transaction: t,
                            accountName: accounts
                                .firstWhereOrNull((a) => a.id == t.accountId)
                                ?.name,
                            transferToAccountName: accounts
                                .firstWhereOrNull(
                                  (a) => a.id == t.transferToAccountId,
                                )
                                ?.name,
                            category: categories
                                .firstWhereOrNull((c) => c.id == t.categoryId),
                            readOnly: widget.readOnly,
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.transactions});

  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    final income = transactions
        .where((t) => t.type == 'income')
        .fold<double>(0, (sum, t) => sum + t.amount);
    final expenses = transactions
        .where((t) => t.type == 'expense')
        .fold<double>(0, (sum, t) => sum + t.amount);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: _SummaryStat(
              label: 'Income',
              value: income,
              color: TransactionColors.income,
            ),
          ),
          Expanded(
            child: _SummaryStat(
              label: 'Expenses',
              value: expenses,
              color: TransactionColors.expense(context),
            ),
          ),
          Expanded(
            child: _SummaryStat(
              label: 'Total',
              value: income - expenses,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 2),
        Text(
          value.toStringAsFixed(2),
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
