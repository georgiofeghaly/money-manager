import 'package:intl/intl.dart';

/// Patterns tried in order; first one that parses every sample wins ties
/// (aside from the explicit dd/MM-vs-MM/dd tie-break below).
const List<String> candidateDateFormats = [
  'yyyy-MM-dd',
  'yyyy/MM/dd',
  'dd/MM/yyyy',
  'MM/dd/yyyy',
  'dd-MM-yyyy',
  'MM-dd-yyyy',
  'dd.MM.yyyy',
  'd MMM yyyy',
  'MMM d, yyyy',
];

class DateFormatDetectionResult {
  const DateFormatDetectionResult({
    required this.pattern,
    required this.ambiguous,
    required this.sampleParses,
  });

  final String pattern;

  /// True when more than one candidate pattern parsed every sample (classic
  /// dd/MM vs MM/dd ambiguity), or when no pattern parsed every sample (a
  /// best-effort partial match was picked instead). Callers should show a
  /// warning banner in either case.
  final bool ambiguous;

  /// Up to 3 parsed samples, for the ambiguity-warning banner preview.
  final List<DateTime> sampleParses;
}

/// Tries each of [candidateDateFormats] against up to 20 non-empty [samples]
/// and returns the first pattern that parses all of them; on a tie between
/// multiple fully-matching patterns, prefers 'dd/MM/yyyy'. If no pattern
/// parses every sample, falls back to whichever parses the most, flagged
/// ambiguous.
DateFormatDetectionResult detectDateFormat(List<String> samples) {
  final nonEmpty =
      samples.map((s) => s.trim()).where((s) => s.isNotEmpty).take(20).toList();

  if (nonEmpty.isEmpty) {
    return const DateFormatDetectionResult(
      pattern: 'yyyy-MM-dd',
      ambiguous: true,
      sampleParses: [],
    );
  }

  final fullMatches = <String>[
    for (final pattern in candidateDateFormats)
      if (_parseCount(pattern, nonEmpty) == nonEmpty.length) pattern,
  ];

  if (fullMatches.isEmpty) {
    var bestPattern = candidateDateFormats.first;
    var bestCount = -1;
    for (final pattern in candidateDateFormats) {
      final count = _parseCount(pattern, nonEmpty);
      if (count > bestCount) {
        bestCount = count;
        bestPattern = pattern;
      }
    }
    return DateFormatDetectionResult(
      pattern: bestPattern,
      ambiguous: true,
      sampleParses: _parseSamples(bestPattern, nonEmpty),
    );
  }

  if (fullMatches.length == 1) {
    return DateFormatDetectionResult(
      pattern: fullMatches.single,
      ambiguous: false,
      sampleParses: _parseSamples(fullMatches.single, nonEmpty),
    );
  }

  final chosen =
      fullMatches.contains('dd/MM/yyyy') ? 'dd/MM/yyyy' : fullMatches.first;
  return DateFormatDetectionResult(
    pattern: chosen,
    ambiguous: true,
    sampleParses: _parseSamples(chosen, nonEmpty),
  );
}

/// Parses [value] with [pattern], returning null (never throwing) on failure
/// — used by the importer to turn a per-row per-row error rather than a
/// crash for unparseable dates.
DateTime? tryParseDate(String pattern, String value) {
  try {
    return DateFormat(pattern).parseStrict(value.trim());
  } on FormatException {
    return null;
  }
}

int _parseCount(String pattern, List<String> samples) {
  var count = 0;
  for (final s in samples) {
    if (tryParseDate(pattern, s) != null) count++;
  }
  return count;
}

List<DateTime> _parseSamples(String pattern, List<String> samples) {
  final result = <DateTime>[];
  for (final s in samples) {
    if (result.length == 3) break;
    final parsed = tryParseDate(pattern, s);
    if (parsed != null) result.add(parsed);
  }
  return result;
}
