import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/core/db/database.dart';
import 'package:money_manager/features/import_export/data/transaction_csv_exporter.dart';

Transaction _transaction({
  required String id,
  required String type,
  required double amount,
  required DateTime occurredAt,
  required String accountId,
  String? transferToAccountId,
  String? categoryId,
  String? note,
}) {
  return Transaction(
    id: id,
    userId: 'local',
    type: type,
    amount: amount,
    occurredAt: occurredAt,
    accountId: accountId,
    transferToAccountId: transferToAccountId,
    categoryId: categoryId,
    note: note,
    updatedAt: occurredAt,
    version: 1,
    syncStatus: 'synced',
  );
}

void main() {
  test('empty transaction list produces just the header row', () {
    final csv = exportTransactionsCsv(
      transactions: const [],
      accountNamesById: const {},
      categoryNamesById: const {},
    );
    expect(csv, 'Date,Type,Amount,Account,Transfer To Account,Category,Note');
  });

  test('builds the exact expected row, including quoting a note with a comma', () {
    final csv = exportTransactionsCsv(
      transactions: [
        _transaction(
          id: 't1',
          type: 'expense',
          amount: 42.5,
          occurredAt: DateTime(2026, 1, 5),
          accountId: 'acc1',
          categoryId: 'cat1',
          note: 'Milk, eggs, bread',
        ),
      ],
      accountNamesById: const {'acc1': 'Cash'},
      categoryNamesById: const {'cat1': 'Groceries'},
    );

    final lines = csv.split('\r\n');
    expect(lines[0], 'Date,Type,Amount,Account,Transfer To Account,Category,Note');
    expect(
      lines[1],
      '2026-01-05,expense,42.5,Cash,,Groceries,"Milk, eggs, bread"',
    );
  });

  test('transfer row includes the destination account, blank category', () {
    final csv = exportTransactionsCsv(
      transactions: [
        _transaction(
          id: 't2',
          type: 'transfer',
          amount: 100,
          occurredAt: DateTime(2026, 2, 1),
          accountId: 'acc1',
          transferToAccountId: 'acc2',
        ),
      ],
      accountNamesById: const {'acc1': 'Cash', 'acc2': 'Savings'},
      categoryNamesById: const {},
    );
    final lines = csv.split('\r\n');
    expect(lines[1], '2026-02-01,transfer,100.0,Cash,Savings,,');
  });

  test('unresolvable account/category ids fall back to blank, not a crash', () {
    final csv = exportTransactionsCsv(
      transactions: [
        _transaction(
          id: 't3',
          type: 'expense',
          amount: 10,
          occurredAt: DateTime(2026, 3, 1),
          accountId: 'missing-account',
          categoryId: 'missing-category',
        ),
      ],
      accountNamesById: const {},
      categoryNamesById: const {},
    );
    final lines = csv.split('\r\n');
    expect(lines[1], '2026-03-01,expense,10.0,,,,');
  });
}
