import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/core/db/database.dart';
import 'package:money_manager/features/transactions/data/transaction_search.dart';

Account _account(String id, String name) => Account(
      id: id,
      userId: 'local',
      name: name,
      type: 'cash',
      startingBalance: 0,
      updatedAt: DateTime(2026),
      version: 1,
      syncStatus: 'synced',
    );

Category _category(String id, String name, {String kind = 'expense'}) => Category(
      id: id,
      kind: kind,
      name: name,
      isSeed: false,
      updatedAt: DateTime(2026),
      version: 1,
      syncStatus: 'synced',
    );

Transaction _transaction({
  required String id,
  String type = 'expense',
  String accountId = 'acc1',
  String? transferToAccountId,
  String? categoryId,
  String? note,
}) =>
    Transaction(
      id: id,
      userId: 'local',
      type: type,
      amount: 10,
      occurredAt: DateTime(2026, 1, 1),
      accountId: accountId,
      transferToAccountId: transferToAccountId,
      categoryId: categoryId,
      note: note,
      updatedAt: DateTime(2026, 1, 1),
      version: 1,
      syncStatus: 'synced',
    );

void main() {
  final accounts = [_account('acc1', 'Cash'), _account('acc2', 'Savings')];
  final categories = [_category('cat1', 'Groceries')];

  group('applyTextSearch', () {
    test('null/empty text returns all rows unchanged', () {
      final rows = [_transaction(id: 't1', note: 'Milk')];
      expect(applyTextSearch(rows, null, accounts, categories), rows);
      expect(applyTextSearch(rows, '', accounts, categories), rows);
      expect(applyTextSearch(rows, '   ', accounts, categories), rows);
    });

    test('matches note, case-insensitively', () {
      final rows = [
        _transaction(id: 't1', note: 'Grocery run'),
        _transaction(id: 't2', note: 'Gas'),
      ];
      final result = applyTextSearch(rows, 'GROCERY', accounts, categories);
      expect(result.map((t) => t.id), ['t1']);
    });

    test('matches resolved account name', () {
      final rows = [_transaction(id: 't1', accountId: 'acc2')];
      final result = applyTextSearch(rows, 'savings', accounts, categories);
      expect(result.map((t) => t.id), ['t1']);
    });

    test('matches resolved transfer destination account name', () {
      final rows = [
        _transaction(id: 't1', type: 'transfer', accountId: 'acc1', transferToAccountId: 'acc2'),
      ];
      final result = applyTextSearch(rows, 'savings', accounts, categories);
      expect(result.map((t) => t.id), ['t1']);
    });

    test('matches resolved category name', () {
      final rows = [_transaction(id: 't1', categoryId: 'cat1')];
      final result = applyTextSearch(rows, 'grocer', accounts, categories);
      expect(result.map((t) => t.id), ['t1']);
    });

    test('no match anywhere excludes the row', () {
      final rows = [_transaction(id: 't1', note: 'Gas', accountId: 'acc1')];
      expect(applyTextSearch(rows, 'zzz', accounts, categories), isEmpty);
    });
  });
}
