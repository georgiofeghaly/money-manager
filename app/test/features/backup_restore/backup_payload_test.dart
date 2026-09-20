import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/core/db/database.dart';
import 'package:money_manager/features/backup_restore/data/backup_payload.dart';

void main() {
  final account = Account(
    id: 'acc1',
    userId: 'local',
    name: 'Cash',
    type: 'cash',
    startingBalance: 100,
    archivedAt: DateTime(2026, 5, 1),
    updatedAt: DateTime(2026, 1, 1),
    version: 2,
    syncStatus: 'synced',
  );
  final category = Category(
    id: 'cat1',
    kind: 'expense',
    name: 'Groceries',
    icon: 'groceries',
    color: 0xFF26A69A,
    isSeed: false,
    updatedAt: DateTime(2026, 1, 1),
    version: 1,
    syncStatus: 'synced',
  );
  final transaction = Transaction(
    id: 't1',
    userId: 'local',
    type: 'expense',
    amount: 42.5,
    occurredAt: DateTime(2026, 1, 5),
    accountId: 'acc1',
    categoryId: 'cat1',
    note: 'Milk',
    updatedAt: DateTime(2026, 1, 5),
    version: 1,
    deletedAt: DateTime(2026, 1, 6),
    syncStatus: 'synced',
  );
  final budget = Budget(
    id: 'b1',
    userId: 'local',
    categoryId: 'cat1',
    periodMonth: DateTime(2026, 1, 1),
    limitAmount: 300,
    updatedAt: DateTime(2026, 1, 1),
    version: 1,
    syncStatus: 'synced',
  );

  test('round-trips through toJson -> jsonEncode -> jsonDecode -> fromJson', () {
    final original = BackupPayload(
      formatVersion: kBackupFormatVersion,
      schemaVersion: 3,
      exportedAt: DateTime(2026, 8, 21, 10, 30),
      accounts: [account.toJson()],
      categories: [category.toJson()],
      transactions: [transaction.toJson()],
      budgets: [budget.toJson()],
    );

    final encoded = jsonEncode(original.toJson());
    final decoded = BackupPayload.fromJson(jsonDecode(encoded) as Map<String, dynamic>);

    expect(decoded.formatVersion, original.formatVersion);
    expect(decoded.schemaVersion, original.schemaVersion);
    expect(decoded.exportedAt, original.exportedAt);

    final decodedAccount = Account.fromJson(decoded.accounts.single);
    expect(decodedAccount.id, account.id);
    expect(decodedAccount.name, account.name);
    expect(decodedAccount.archivedAt, account.archivedAt);

    final decodedCategory = Category.fromJson(decoded.categories.single);
    expect(decodedCategory.color, category.color);

    final decodedTransaction = Transaction.fromJson(decoded.transactions.single);
    expect(decodedTransaction.amount, transaction.amount);
    expect(decodedTransaction.occurredAt, transaction.occurredAt);
    // deletedAt surviving the round-trip is the whole point of a
    // byte-faithful backup — a restore must not silently un-delete rows.
    expect(decodedTransaction.deletedAt, transaction.deletedAt);

    final decodedBudget = Budget.fromJson(decoded.budgets.single);
    expect(decodedBudget.limitAmount, budget.limitAmount);
    expect(decodedBudget.periodMonth, budget.periodMonth);
  });

  test('empty tables round-trip to empty lists, not errors', () {
    final payload = BackupPayload(
      formatVersion: kBackupFormatVersion,
      schemaVersion: 3,
      exportedAt: DateTime(2026),
      accounts: const [],
      categories: const [],
      transactions: const [],
      budgets: const [],
    );
    final decoded = BackupPayload.fromJson(jsonDecode(jsonEncode(payload.toJson())) as Map<String, dynamic>);
    expect(decoded.accounts, isEmpty);
    expect(decoded.transactions, isEmpty);
  });
}
