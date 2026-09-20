// Shared fuzzy string matching used by both column_mapper.dart (CSV header
// -> transaction field) and category_matcher.dart (CSV category text ->
// existing Category).

/// Classic edit-distance between two strings.
int levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  var previousRow = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 0; i < a.length; i++) {
    final currentRow = List<int>.filled(b.length + 1, 0);
    currentRow[0] = i + 1;
    for (var j = 0; j < b.length; j++) {
      final deletionCost = previousRow[j + 1] + 1;
      final insertionCost = currentRow[j] + 1;
      final substitutionCost = previousRow[j] + (a[i] == b[j] ? 0 : 1);
      currentRow[j + 1] =
          [deletionCost, insertionCost, substitutionCost].reduce(
        (x, y) => x < y ? x : y,
      );
    }
    previousRow = currentRow;
  }
  return previousRow[b.length];
}

/// 1.0 = identical, 0.0 = completely different.
double similarity(String a, String b) {
  if (a.isEmpty && b.isEmpty) return 1;
  final maxLen = a.length > b.length ? a.length : b.length;
  if (maxLen == 0) return 1;
  return 1 - levenshtein(a, b) / maxLen;
}
