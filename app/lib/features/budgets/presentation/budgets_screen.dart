import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/database.dart';
import '../../../core/theme/category_style.dart';
import '../../categories/application/category_providers.dart';
import '../application/budget_providers.dart';
import '../data/budget_repository.dart';
import 'budget_form_sheet.dart';

class BudgetsScreen extends ConsumerStatefulWidget {
  const BudgetsScreen({super.key});

  @override
  ConsumerState<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends ConsumerState<BudgetsScreen> {
  DateTime _month = normalizeMonth(DateTime.now());

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
  }

  @override
  Widget build(BuildContext context) {
    final budgetsAsync = ref.watch(budgetsForMonthProvider(_month));
    final categoriesAsync = ref.watch(categoriesAllForLookupProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
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
      ),
      body: budgetsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
        data: (budgets) {
          final categories = categoriesAsync.valueOrNull ?? const [];

          if (budgets.isEmpty) {
            return _EmptyBudgets(month: _month);
          }

          return ListView.builder(
            itemCount: budgets.length,
            itemBuilder: (context, index) {
              final budget = budgets[index];
              final category =
                  categories.firstWhereOrNull((c) => c.id == budget.categoryId);
              return _BudgetTile(
                budget: budget,
                category: category,
                month: _month,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          final excluded =
              (budgetsAsync.valueOrNull ?? const <Budget>[]).map((b) => b.categoryId).toSet();
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) =>
                BudgetFormSheet(month: _month, excludedCategoryIds: excluded),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _EmptyBudgets extends ConsumerWidget {
  const _EmptyBudgets({required this.month});
  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previousMonth = DateTime(month.year, month.month - 1, 1);
    final previousBudgetsAsync = ref.watch(budgetsForMonthProvider(previousMonth));
    final hasPrevious = (previousBudgetsAsync.valueOrNull ?? const []).isNotEmpty;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('No budgets set for this month.'),
          if (hasPrevious) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () async {
                await ref.read(budgetRepositoryProvider).copyFromPreviousMonth(month);
              },
              child: const Text('Copy last month\'s budgets'),
            ),
          ],
        ],
      ),
    );
  }
}

class _BudgetTile extends ConsumerWidget {
  const _BudgetTile({
    required this.budget,
    required this.category,
    required this.month,
  });

  final Budget budget;
  final Category? category;
  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spentAsync =
        ref.watch(budgetSpentProvider(BudgetSpentKey(budget.categoryId, month)));
    final color = colorFromArgb(category?.color, category?.id ?? budget.id);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color,
        foregroundColor: Colors.white,
        child: Icon(iconForKey(category?.icon)),
      ),
      title: Text(category?.name ?? 'Unknown category'),
      subtitle: spentAsync.when(
        loading: () => const LinearProgressIndicator(),
        error: (err, st) => const Text('—'),
        data: (spent) {
          final ratio = budget.limitAmount == 0
              ? 0.0
              : (spent / budget.limitAmount).clamp(0.0, 1.0);
          final overBudget = spent > budget.limitAmount;
          return Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    color: overBudget ? Theme.of(context).colorScheme.error : color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${spent.toStringAsFixed(2)} / ${budget.limitAmount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: overBudget ? Theme.of(context).colorScheme.error : null,
                  ),
                ),
              ],
            ),
          );
        },
      ),
      isThreeLine: true,
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => BudgetFormSheet(
          month: month,
          existing: budget,
          existingCategory: category,
        ),
      ),
    );
  }
}
