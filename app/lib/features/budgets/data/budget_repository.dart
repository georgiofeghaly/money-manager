import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/database.dart';

const _uuid = Uuid();

DateTime normalizeMonth(DateTime d) => DateTime(d.year, d.month, 1);

class BudgetRepository {
  BudgetRepository(this._db);

  final AppDatabase _db;

  Stream<List<Budget>> watchBudgetsForMonth(DateTime month) {
    final normalized = normalizeMonth(month);
    return (_db.select(_db.budgets)
          ..where((b) =>
              b.deletedAt.isNull() & b.periodMonth.equals(normalized))
          ..orderBy([(b) => OrderingTerm.asc(b.categoryId)]))
        .watch();
  }

  /// Sum of that category's expenses within [month], for the progress bar.
  Stream<double> watchSpent(String categoryId, DateTime month) {
    final start = normalizeMonth(month);
    final end = DateTime(start.year, start.month + 1, 1);
    final query = _db.customSelect(
      '''
      SELECT COALESCE(SUM(amount), 0) AS spent
      FROM transactions
      WHERE category_id = :categoryId
        AND type = 'expense'
        AND deleted_at IS NULL
        AND occurred_at >= :start
        AND occurred_at < :end
      ''',
      variables: [
        Variable.withString(categoryId),
        Variable.withDateTime(start),
        Variable.withDateTime(end),
      ],
      readsFrom: {_db.transactions},
    );
    return query.watchSingle().map((row) => row.read<double>('spent'));
  }

  /// Inserts a new budget for (categoryId, month), or updates the limit if
  /// one already exists — looked up explicitly rather than relying on a SQL
  /// upsert, since the conflict target is the (category, month) unique key,
  /// not the primary key (a fresh UUID is generated for every insert).
  Future<void> upsertBudget({
    required String categoryId,
    required DateTime month,
    required double limitAmount,
  }) async {
    final normalized = normalizeMonth(month);
    final existing = await (_db.select(_db.budgets)
          ..where((b) =>
              b.deletedAt.isNull() &
              b.categoryId.equals(categoryId) &
              b.periodMonth.equals(normalized)))
        .getSingleOrNull();

    final now = DateTime.now();
    if (existing != null) {
      await (_db.update(_db.budgets)..where((b) => b.id.equals(existing.id)))
          .write(BudgetsCompanion(
        limitAmount: Value(limitAmount),
        updatedAt: Value(now),
      ));
    } else {
      await _db.into(_db.budgets).insert(BudgetsCompanion.insert(
            id: _uuid.v4(),
            categoryId: categoryId,
            periodMonth: normalized,
            limitAmount: limitAmount,
            updatedAt: now,
          ));
    }
  }

  Future<void> deleteBudget(String id) {
    return (_db.update(_db.budgets)..where((b) => b.id.equals(id))).write(
      BudgetsCompanion(deletedAt: Value(DateTime.now())),
    );
  }

  /// Copies every budget from the month before [month] into [month], skipping
  /// categories that already have a budget set for [month].
  Future<void> copyFromPreviousMonth(DateTime month) async {
    final target = normalizeMonth(month);
    final previous = DateTime(target.year, target.month - 1, 1);

    final previousBudgets = await (_db.select(_db.budgets)
          ..where((b) => b.deletedAt.isNull() & b.periodMonth.equals(previous)))
        .get();
    final existingCategoryIds = (await (_db.select(_db.budgets)
              ..where((b) =>
                  b.deletedAt.isNull() & b.periodMonth.equals(target)))
            .get())
        .map((b) => b.categoryId)
        .toSet();

    final now = DateTime.now();
    final toInsert = previousBudgets
        .where((b) => !existingCategoryIds.contains(b.categoryId))
        .map((b) => BudgetsCompanion.insert(
              id: _uuid.v4(),
              categoryId: b.categoryId,
              periodMonth: target,
              limitAmount: b.limitAmount,
              updatedAt: now,
            ))
        .toList();

    if (toInsert.isEmpty) return;
    await _db.batch((batch) => batch.insertAll(_db.budgets, toInsert));
  }
}
