import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/core/db/database.dart';
import 'package:money_manager/features/import_export/data/category_matcher.dart';

Category _category(String id, String name, {String kind = 'expense'}) {
  return Category(
    id: id,
    kind: kind,
    name: name,
    isSeed: false,
    updatedAt: DateTime(2026),
    version: 1,
    syncStatus: 'synced',
  );
}

void main() {
  final existing = [
    _category('1', 'Groceries'),
    _category('2', 'Dining'),
    _category('3', 'Bills & Utilities'),
  ];

  group('matchCategory', () {
    test('exact (case/whitespace-insensitive) match', () {
      final result = matchCategory('  groceries  ', existing);
      expect(result.suggested?.id, '1');
      expect(result.score, 1.0);
    });

    test('near-miss typo still matches', () {
      final result = matchCategory('Dinning', existing);
      expect(result.suggested?.id, '2');
    });

    test('below-threshold falls back to no suggestion (create new)', () {
      final result = matchCategory('Freelance Income', existing);
      expect(result.suggested, isNull);
      expect(result.score, lessThan(categoryMatchThreshold));
    });

    test('empty candidate list never matches', () {
      final result = matchCategory('Groceries', const []);
      expect(result.suggested, isNull);
    });
  });
}
