import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/features/import_export/data/column_mapper.dart';
import 'package:money_manager/features/import_export/data/fuzzy_match.dart';

void main() {
  group('levenshtein', () {
    test('identical strings', () => expect(levenshtein('abc', 'abc'), 0));
    test('empty vs empty', () => expect(levenshtein('', ''), 0));
    test('empty vs non-empty', () => expect(levenshtein('', 'abc'), 3));
    test('completely different', () => expect(levenshtein('abc', 'xyz'), 3));
    test('single substitution', () => expect(levenshtein('cat', 'bat'), 1));
  });

  group('guessColumnMapping', () {
    test('maps a Mint-style header set', () {
      final headers = ['Date', 'Description', 'Amount', 'Category'];
      final mapping = guessColumnMapping(headers);
      expect(mapping[0], ImportField.date);
      expect(mapping[1], ImportField.note);
      expect(mapping[2], ImportField.amount);
      expect(mapping[3], ImportField.category);
    });

    test('maps a bank-style Debit/Credit header set', () {
      final headers = ['Transaction Date', 'Debit', 'Credit', 'Memo'];
      final mapping = guessColumnMapping(headers);
      expect(mapping[0], ImportField.date);
      expect(mapping[1], ImportField.debit);
      expect(mapping[2], ImportField.credit);
      expect(mapping[3], ImportField.note);
    });

    test('leaves an unrecognized column unmapped', () {
      final headers = ['Date', 'Amount', 'Reference Number'];
      final mapping = guessColumnMapping(headers);
      expect(mapping.containsKey(2), isFalse);
    });

    test('never assigns the same field to two columns', () {
      final headers = ['Date', 'Date2', 'Amount'];
      final mapping = guessColumnMapping(headers);
      final assignedFields = mapping.values.toList();
      expect(assignedFields.toSet().length, assignedFields.length);
    });
  });
}
