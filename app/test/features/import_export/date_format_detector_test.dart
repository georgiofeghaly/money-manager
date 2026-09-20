import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/features/import_export/data/date_format_detector.dart';

void main() {
  group('detectDateFormat', () {
    test('unambiguous ISO samples', () {
      final result = detectDateFormat(['2026-01-05', '2026-02-28', '2026-12-31']);
      expect(result.pattern, 'yyyy-MM-dd');
      expect(result.ambiguous, isFalse);
    });

    test('unambiguous US-style samples (day > 12 disambiguates)', () {
      final result = detectDateFormat(['03/25/2026', '11/02/2026']);
      expect(result.pattern, 'MM/dd/yyyy');
      expect(result.ambiguous, isFalse);
    });

    test('ambiguous dd/MM vs MM/dd (all days <= 12) defaults to dd/MM/yyyy', () {
      final result = detectDateFormat(['01/02/2026', '03/04/2026']);
      expect(result.pattern, 'dd/MM/yyyy');
      expect(result.ambiguous, isTrue);
    });

    test('garbage input falls back to a best-effort pattern, flagged ambiguous', () {
      final result = detectDateFormat(['not a date', 'also not a date']);
      expect(result.ambiguous, isTrue);
    });

    test('empty sample list', () {
      final result = detectDateFormat([]);
      expect(result.ambiguous, isTrue);
      expect(result.sampleParses, isEmpty);
    });
  });

  group('tryParseDate', () {
    test('valid date parses', () {
      expect(tryParseDate('yyyy-MM-dd', '2026-08-21'), DateTime(2026, 8, 21));
    });

    test('invalid date returns null instead of throwing', () {
      expect(tryParseDate('yyyy-MM-dd', 'not a date'), isNull);
    });
  });
}
