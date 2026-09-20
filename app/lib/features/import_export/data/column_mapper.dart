import 'fuzzy_match.dart';

/// The transaction fields a CSV column can be mapped to. Not every field is
/// required for every [AmountStrategy] — see step_account_and_strategy.dart.
enum ImportField {
  date,
  amount,
  debit,
  credit,
  type,
  category,
  note,
}

const Map<ImportField, List<String>> _aliases = {
  ImportField.date: [
    'date',
    'transactiondate',
    'postdate',
    'postingdate',
    'valuedate',
    'trandate',
    'transdate',
  ],
  ImportField.amount: ['amount', 'value', 'total', 'sum'],
  ImportField.debit: ['debit', 'withdrawal', 'moneyout', 'outflow', 'paidout'],
  ImportField.credit: ['credit', 'deposit', 'moneyin', 'inflow', 'paidin'],
  ImportField.type: ['type', 'transactiontype', 'direction'],
  ImportField.category: ['category', 'categoryname', 'tag', 'tags'],
  ImportField.note: [
    'note',
    'notes',
    'memo',
    'description',
    'details',
    'narrative',
    'payee',
  ],
};

String normalizeHeader(String header) =>
    header.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

/// Best (header, field) score across every alias of [field].
double _scoreHeaderForField(String normalizedHeader, ImportField field) {
  var best = 0.0;
  for (final alias in _aliases[field]!) {
    final score = similarity(normalizedHeader, alias);
    if (score > best) best = score;
  }
  return best;
}

/// Greedily assigns each CSV header to its best-scoring still-unclaimed
/// [ImportField], skipping any pair scoring below [threshold]. Returns a map
/// from header index to the field it was guessed to represent — headers with
/// no confident guess are simply absent from the map.
Map<int, ImportField> guessColumnMapping(
  List<String> headers, {
  double threshold = 0.75,
}) {
  final normalized = headers.map(normalizeHeader).toList();

  final candidates = <(int headerIndex, ImportField field, double score)>[];
  for (var i = 0; i < normalized.length; i++) {
    for (final field in ImportField.values) {
      final score = _scoreHeaderForField(normalized[i], field);
      if (score >= threshold) candidates.add((i, field, score));
    }
  }
  candidates.sort((a, b) => b.$3.compareTo(a.$3));

  final result = <int, ImportField>{};
  final claimedFields = <ImportField>{};
  for (final (headerIndex, field, _) in candidates) {
    if (result.containsKey(headerIndex)) continue;
    if (claimedFields.contains(field)) continue;
    result[headerIndex] = field;
    claimedFields.add(field);
  }
  return result;
}
