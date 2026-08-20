import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/database.dart';

const _uuid = Uuid();

class TransactionRepository {
  TransactionRepository(this._db);

  final AppDatabase _db;

  /// [end] is exclusive.
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
          ),
        );
  }

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
      ),
    );
  }

  Future<void> deleteTransaction(String id) {
    return (_db.update(_db.transactions)..where((t) => t.id.equals(id))).write(
      TransactionsCompanion(deletedAt: Value(DateTime.now())),
    );
  }
}
