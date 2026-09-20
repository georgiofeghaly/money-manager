import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/database.dart';
import '../../import_export/data/transaction_draft.dart';
import 'transaction_filter.dart';

const _uuid = Uuid();

abstract class TransactionReader {
  /// [end] is exclusive.
  Stream<List<Transaction>> watchTransactionsInRange(DateTime start, DateTime end);

  Stream<List<Transaction>> watchTransactionsFiltered(TransactionFilter filter);

  /// One-shot (not a live stream) fetch of every non-deleted transaction,
  /// for CSV export — the streams above are all range-bounded.
  Future<List<Transaction>> getAllTransactionsOnce();
}

abstract class TransactionWriter {
  /// Bulk-inserts CSV import drafts, tagging every row with [importBatchId]
  /// so a bad import can be reverted in one shot via [revertImportBatch].
  Future<void> importTransactions(
    List<TransactionDraft> drafts, {
    required String importBatchId,
  });

  /// Soft-deletes every transaction created by a given import, so a bad
  /// import can be undone with one tap.
  Future<void> revertImportBatch(String importBatchId);

  Future<void> createTransaction({
    required String type,
    required double amount,
    required DateTime occurredAt,
    required String accountId,
    String? transferToAccountId,
    String? categoryId,
    String? note,
  });

  Future<void> updateTransaction({
    required String id,
    required String type,
    required double amount,
    required DateTime occurredAt,
    required String accountId,
    String? transferToAccountId,
    String? categoryId,
    String? note,
  });

  Future<void> deleteTransaction(String id);
}

class DriftTransactionRepository implements TransactionReader, TransactionWriter {
  DriftTransactionRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<Transaction>> watchTransactionsInRange(
    DateTime start,
    DateTime end,
  ) {
    return (_db.select(_db.transactions)
          ..where(
            (t) =>
                t.deletedAt.isNull() &
                t.occurredAt.isBiggerOrEqualValue(start) &
                t.occurredAt.isSmallerThanValue(end),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]))
        .watch();
  }

  /// Live search/filter query — every predicate in [filter] is optional and
  /// combined with AND. Text matching against account/category *names*
  /// (rather than just [Transaction.note]) is handled by the caller via
  /// `applyTextSearch` (transaction_search.dart), since that requires
  /// resolving other tables' rows, not a SQL join this method performs.
  @override
  Stream<List<Transaction>> watchTransactionsFiltered(TransactionFilter filter) {
    final query = _db.select(_db.transactions)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.desc(t.occurredAt)]);

    if (filter.type != null) {
      query.where((t) => t.type.equals(filter.type!));
    }
    if (filter.accountIds.isNotEmpty) {
      query.where(
        (t) =>
            t.accountId.isIn(filter.accountIds) |
            t.transferToAccountId.isIn(filter.accountIds),
      );
    }
    if (filter.categoryIds.isNotEmpty) {
      query.where((t) => t.categoryId.isIn(filter.categoryIds));
    }
    if (filter.start != null) {
      query.where((t) => t.occurredAt.isBiggerOrEqualValue(filter.start!));
    }
    if (filter.end != null) {
      query.where((t) => t.occurredAt.isSmallerThanValue(filter.end!));
    }
    if (filter.minAmount != null) {
      query.where((t) => t.amount.isBiggerOrEqualValue(filter.minAmount!));
    }
    if (filter.maxAmount != null) {
      query.where((t) => t.amount.isSmallerOrEqualValue(filter.maxAmount!));
    }

    return query.watch();
  }

  @override
  Future<List<Transaction>> getAllTransactionsOnce() {
    return (_db.select(_db.transactions)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.occurredAt)]))
        .get();
  }

  @override
  Future<void> importTransactions(
    List<TransactionDraft> drafts, {
    required String importBatchId,
  }) {
    final now = DateTime.now();
    final rows = [
      for (final draft in drafts)
        TransactionsCompanion.insert(
          id: _uuid.v4(),
          type: draft.type,
          amount: draft.amount,
          occurredAt: draft.occurredAt,
          accountId: draft.accountId,
          transferToAccountId: Value(draft.transferToAccountId),
          categoryId: Value(draft.categoryId),
          note: Value(draft.note),
          importBatchId: Value(importBatchId),
          updatedAt: now,
          syncStatus: const Value('pending'),
        ),
    ];
    return _db.batch((batch) => batch.insertAll(_db.transactions, rows));
  }

  @override
  Future<void> revertImportBatch(String importBatchId) {
    return (_db.update(_db.transactions)
          ..where(
            (t) =>
                t.importBatchId.equals(importBatchId) & t.deletedAt.isNull(),
          ))
        .write(TransactionsCompanion(
          deletedAt: Value(DateTime.now()),
          syncStatus: const Value('pending'),
        ));
  }

  @override
  Future<void> createTransaction({
    required String type,
    required double amount,
    required DateTime occurredAt,
    required String accountId,
    String? transferToAccountId,
    String? categoryId,
    String? note,
  }) {
    final now = DateTime.now();
    return _db.into(_db.transactions).insert(
          TransactionsCompanion.insert(
            id: _uuid.v4(),
            type: type,
            amount: amount,
            occurredAt: occurredAt,
            accountId: accountId,
            transferToAccountId: Value(transferToAccountId),
            categoryId: Value(categoryId),
            note: Value(note),
            updatedAt: now,
            syncStatus: const Value('pending'),
          ),
        );
  }

  @override
  Future<void> updateTransaction({
    required String id,
    required String type,
    required double amount,
    required DateTime occurredAt,
    required String accountId,
    String? transferToAccountId,
    String? categoryId,
    String? note,
  }) {
    return (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        type: Value(type),
        amount: Value(amount),
        occurredAt: Value(occurredAt),
        accountId: Value(accountId),
        // Explicit Value(null), not absent, so switching away from
        // transfer/expense-with-category actually clears the old field.
        transferToAccountId: Value(transferToAccountId),
        categoryId: Value(categoryId),
        note: Value(note),
        updatedAt: Value(DateTime.now()),
        syncStatus: const Value('pending'),
      ),
    );
  }

  @override
  Future<void> deleteTransaction(String id) {
    return (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(
        deletedAt: Value(DateTime.now()),
        syncStatus: const Value('pending'),
      ),
    );
  }
}
