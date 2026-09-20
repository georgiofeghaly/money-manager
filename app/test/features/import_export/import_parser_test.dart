import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/features/import_export/data/column_mapper.dart';
import 'package:money_manager/features/import_export/data/import_parser.dart';

void main() {
  group('parseImportRows - signedAmount', () {
    test('parses income and expense from signed amount, resolving categories', () {
      final result = parseImportRows(
        dataRows: [
          ['2026-01-05', '-42.50', 'Groceries', 'Milk'],
          ['2026-01-06', '100.00', 'Salary', ''],
        ],
        fieldColumns: {
          ImportField.date: 0,
          ImportField.amount: 1,
          ImportField.category: 2,
          ImportField.note: 3,
        },
        strategy: AmountStrategy.signedAmount,
        dateFormatPattern: 'yyyy-MM-dd',
        accountId: 'acct-1',
        categoryResolutions: {
          'Groceries': const CategoryResolution.useExisting('cat-groceries'),
          'Salary': const CategoryResolution.createNew('Salary'),
        },
      );

      expect(result.errors, isEmpty);
      expect(result.rows, hasLength(2));

      final expense = result.rows[0];
      expect(expense.type, 'expense');
      expect(expense.amount, 42.50);
      expect(expense.categoryId, 'cat-groceries');
      expect(expense.note, 'Milk');

      final income = result.rows[1];
      expect(income.type, 'income');
      expect(income.amount, 100.0);
      expect(income.pendingCategoryKey, 'income|salary');
      expect(result.pendingCategories['income|salary']?.name, 'Salary');
    });

    test('zero amount is an error', () {
      final result = parseImportRows(
        dataRows: [
          ['2026-01-05', '0']
        ],
        fieldColumns: {ImportField.date: 0, ImportField.amount: 1},
        strategy: AmountStrategy.signedAmount,
        dateFormatPattern: 'yyyy-MM-dd',
        accountId: 'acct-1',
        categoryResolutions: const {},
      );
      expect(result.rows, isEmpty);
      expect(result.errors.single.reason, contains('Zero amount'));
    });

    test('invalid date is an error', () {
      final result = parseImportRows(
        dataRows: [
          ['not-a-date', '10']
        ],
        fieldColumns: {ImportField.date: 0, ImportField.amount: 1},
        strategy: AmountStrategy.signedAmount,
        dateFormatPattern: 'yyyy-MM-dd',
        accountId: 'acct-1',
        categoryResolutions: const {},
      );
      expect(result.rows, isEmpty);
      expect(result.errors.single.reason, contains('date'));
    });

    test('missing amount cell is an error', () {
      final result = parseImportRows(
        dataRows: [
          ['2026-01-05']
        ],
        fieldColumns: {ImportField.date: 0, ImportField.amount: 1},
        strategy: AmountStrategy.signedAmount,
        dateFormatPattern: 'yyyy-MM-dd',
        accountId: 'acct-1',
        categoryResolutions: const {},
      );
      expect(result.errors.single.reason, contains('Invalid amount'));
    });
  });

  group('parseImportRows - debitCredit', () {
    test('debit column produces an expense', () {
      final result = parseImportRows(
        dataRows: [
          ['2026-01-05', '20.00', '']
        ],
        fieldColumns: {ImportField.date: 0, ImportField.debit: 1, ImportField.credit: 2},
        strategy: AmountStrategy.debitCredit,
        dateFormatPattern: 'yyyy-MM-dd',
        accountId: 'acct-1',
        categoryResolutions: const {},
      );
      expect(result.rows.single.type, 'expense');
      expect(result.rows.single.amount, 20.0);
    });

    test('credit column produces income', () {
      final result = parseImportRows(
        dataRows: [
          ['2026-01-05', '', '20.00']
        ],
        fieldColumns: {ImportField.date: 0, ImportField.debit: 1, ImportField.credit: 2},
        strategy: AmountStrategy.debitCredit,
        dateFormatPattern: 'yyyy-MM-dd',
        accountId: 'acct-1',
        categoryResolutions: const {},
      );
      expect(result.rows.single.type, 'income');
    });

    test('both debit and credit set is an error', () {
      final result = parseImportRows(
        dataRows: [
          ['2026-01-05', '5', '5']
        ],
        fieldColumns: {ImportField.date: 0, ImportField.debit: 1, ImportField.credit: 2},
        strategy: AmountStrategy.debitCredit,
        dateFormatPattern: 'yyyy-MM-dd',
        accountId: 'acct-1',
        categoryResolutions: const {},
      );
      expect(result.errors.single.reason, contains('Both debit and credit'));
    });

    test('neither debit nor credit set is an error', () {
      final result = parseImportRows(
        dataRows: [
          ['2026-01-05', '', '']
        ],
        fieldColumns: {ImportField.date: 0, ImportField.debit: 1, ImportField.credit: 2},
        strategy: AmountStrategy.debitCredit,
        dateFormatPattern: 'yyyy-MM-dd',
        accountId: 'acct-1',
        categoryResolutions: const {},
      );
      expect(result.errors.single.reason, contains('Missing debit/credit'));
    });
  });

  group('parseImportRows - amountPlusType', () {
    test('type column maps expense/income aliases', () {
      final result = parseImportRows(
        dataRows: [
          ['2026-01-05', '10', 'debit'],
          ['2026-01-06', '10', 'credit'],
        ],
        fieldColumns: {ImportField.date: 0, ImportField.amount: 1, ImportField.type: 2},
        strategy: AmountStrategy.amountPlusType,
        dateFormatPattern: 'yyyy-MM-dd',
        accountId: 'acct-1',
        categoryResolutions: const {},
      );
      expect(result.rows[0].type, 'expense');
      expect(result.rows[1].type, 'income');
    });

    test('transfer type is not supported and errors', () {
      final result = parseImportRows(
        dataRows: [
          ['2026-01-05', '10', 'transfer']
        ],
        fieldColumns: {ImportField.date: 0, ImportField.amount: 1, ImportField.type: 2},
        strategy: AmountStrategy.amountPlusType,
        dateFormatPattern: 'yyyy-MM-dd',
        accountId: 'acct-1',
        categoryResolutions: const {},
      );
      expect(result.rows, isEmpty);
      expect(result.errors.single.reason, contains('Transfers'));
    });

    test('unrecognized type value errors', () {
      final result = parseImportRows(
        dataRows: [
          ['2026-01-05', '10', 'mystery']
        ],
        fieldColumns: {ImportField.date: 0, ImportField.amount: 1, ImportField.type: 2},
        strategy: AmountStrategy.amountPlusType,
        dateFormatPattern: 'yyyy-MM-dd',
        accountId: 'acct-1',
        categoryResolutions: const {},
      );
      expect(result.errors.single.reason, contains('Unrecognized type'));
    });
  });

  group('category resolution', () {
    test('skip resolution excludes the row with a Skipped reason', () {
      final result = parseImportRows(
        dataRows: [
          ['2026-01-05', '-10', 'Fees']
        ],
        fieldColumns: {ImportField.date: 0, ImportField.amount: 1, ImportField.category: 2},
        strategy: AmountStrategy.signedAmount,
        dateFormatPattern: 'yyyy-MM-dd',
        accountId: 'acct-1',
        categoryResolutions: {'Fees': const CategoryResolution.skip()},
      );
      expect(result.rows, isEmpty);
      expect(result.errors.single.reason, contains('Skipped'));
    });

    test('a category missing from the resolutions map errors', () {
      final result = parseImportRows(
        dataRows: [
          ['2026-01-05', '-10', 'Fees']
        ],
        fieldColumns: {ImportField.date: 0, ImportField.amount: 1, ImportField.category: 2},
        strategy: AmountStrategy.signedAmount,
        dateFormatPattern: 'yyyy-MM-dd',
        accountId: 'acct-1',
        categoryResolutions: const {},
      );
      expect(result.rows, isEmpty);
      expect(result.errors.single.reason, contains('not resolved'));
    });

    test('a blank category cell needs no resolution', () {
      final result = parseImportRows(
        dataRows: [
          ['2026-01-05', '-10', '']
        ],
        fieldColumns: {ImportField.date: 0, ImportField.amount: 1, ImportField.category: 2},
        strategy: AmountStrategy.signedAmount,
        dateFormatPattern: 'yyyy-MM-dd',
        accountId: 'acct-1',
        categoryResolutions: const {},
      );
      expect(result.rows.single.categoryId, isNull);
      expect(result.rows.single.pendingCategoryKey, isNull);
    });
  });

  group('collectCategoryUsages', () {
    test('dedupes by (kind, normalized text) and skips rows with no resolvable amount', () {
      final usages = collectCategoryUsages(
        dataRows: [
          ['-10', 'Groceries'],
          ['-5', ' groceries '],
          ['10', 'Groceries'],
          ['abc', 'ShouldBeSkipped'],
        ],
        fieldColumns: {ImportField.amount: 0, ImportField.category: 1},
        strategy: AmountStrategy.signedAmount,
      );
      expect(usages, hasLength(2));
      expect(usages.map((u) => u.kind).toSet(), {'expense', 'income'});
    });
  });
}
