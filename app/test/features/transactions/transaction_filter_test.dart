import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/features/transactions/data/transaction_filter.dart';

void main() {
  group('TransactionFilter equality', () {
    test('two default filters are equal', () {
      expect(const TransactionFilter(), const TransactionFilter());
    });

    test('sets built from different List instances with the same content are equal', () {
      final a = TransactionFilter(accountIds: {'1', '2'});
      final b = TransactionFilter(accountIds: {..._listOf('2', '1')});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differing text makes filters unequal', () {
      const a = TransactionFilter(text: 'coffee');
      const b = TransactionFilter(text: 'tea');
      expect(a, isNot(b));
    });

    test('differing accountIds makes filters unequal', () {
      final a = TransactionFilter(accountIds: const {'1'});
      final b = TransactionFilter(accountIds: const {'2'});
      expect(a, isNot(b));
    });

    test('differing date range makes filters unequal', () {
      final a = TransactionFilter(start: DateTime(2026, 1, 1));
      final b = TransactionFilter(start: DateTime(2026, 2, 1));
      expect(a, isNot(b));
    });
  });

  group('TransactionFilter.isEmpty', () {
    test('default filter is empty', () {
      expect(const TransactionFilter().isEmpty, isTrue);
    });

    test('blank text is treated as empty', () {
      expect(const TransactionFilter(text: '   ').isEmpty, isTrue);
    });

    test('any single predicate makes it non-empty', () {
      expect(const TransactionFilter(type: 'expense').isEmpty, isFalse);
      expect(TransactionFilter(accountIds: const {'1'}).isEmpty, isFalse);
      expect(const TransactionFilter(minAmount: 10).isEmpty, isFalse);
    });
  });

  group('TransactionFilter.copyWith', () {
    test('clear flags null out the field regardless of other args', () {
      const original = TransactionFilter(text: 'x', type: 'expense', minAmount: 5);
      final cleared = original.copyWith(clearText: true, clearType: true, clearMinAmount: true);
      expect(cleared.text, isNull);
      expect(cleared.type, isNull);
      expect(cleared.minAmount, isNull);
    });

    test('unspecified fields are preserved', () {
      const original = TransactionFilter(text: 'x', minAmount: 5);
      final updated = original.copyWith(type: 'income');
      expect(updated.text, 'x');
      expect(updated.minAmount, 5);
      expect(updated.type, 'income');
    });
  });
}

Iterable<String> _listOf(String a, String b) => [a, b];
