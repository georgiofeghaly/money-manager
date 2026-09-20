import '../../core/db/database.dart';
import '../../features/budgets/data/budget_repository.dart';
import 'watch_derived.dart';
import 'web_data_store.dart';

class ApiBudgetRepository implements BudgetReader {
  ApiBudgetRepository(this._store);

  final WebDataStore _store;

  @override
  Stream<List<Budget>> watchBudgetsForMonth(DateTime month) => watchDerived(_store, () {
        final normalized = normalizeMonth(month);
        final rows = _store.budgets
            .where((b) => b.deletedAt == null && b.periodMonth == normalized)
            .toList()
          ..sort((a, b) => a.categoryId.compareTo(b.categoryId));
        return rows;
      });

  @override
  Stream<double> watchSpent(String categoryId, DateTime month) => watchDerived(_store, () {
        final start = normalizeMonth(month);
        final end = DateTime(start.year, start.month + 1, 1);
        var spent = 0.0;
        for (final t in _store.transactions) {
          if (t.deletedAt != null) continue;
          if (t.categoryId != categoryId) continue;
          if (t.type != 'expense') continue;
          if (t.occurredAt.isBefore(start) || !t.occurredAt.isBefore(end)) continue;
          spent += t.amount;
        }
        return spent;
      });
}
