import '../../../core/db/database.dart';
import 'fuzzy_match.dart';

/// Below this similarity, [matchCategory] suggests "create new" instead of
/// an existing category.
const categoryMatchThreshold = 0.6;

class CategoryMatch {
  const CategoryMatch({
    required this.rawText,
    required this.suggested,
    required this.score,
  });

  /// The raw category string as it appeared in the CSV.
  final String rawText;

  /// The best-matching existing category of the row's kind, or null if
  /// nothing scored above [categoryMatchThreshold] — the resolution UI
  /// should default to "create new" in that case.
  final Category? suggested;

  final double score;
}

String normalizeCategoryText(String text) =>
    text.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

/// Fuzzy-matches [rawText] (a raw CSV category value) against [existingOfKind]
/// (existing categories already filtered to the row's inferred income/expense
/// kind) and returns the best suggestion, if any.
CategoryMatch matchCategory(String rawText, List<Category> existingOfKind) {
  final normalizedRaw = normalizeCategoryText(rawText);

  Category? best;
  var bestScore = 0.0;
  for (final category in existingOfKind) {
    final score = similarity(normalizedRaw, normalizeCategoryText(category.name));
    if (score > bestScore) {
      bestScore = score;
      best = category;
    }
  }

  return CategoryMatch(
    rawText: rawText,
    suggested: bestScore >= categoryMatchThreshold ? best : null,
    score: bestScore,
  );
}
