import 'package:csv/csv.dart';

/// Parses raw CSV text into rows of string cells (numbers are left as text —
/// the importer parses amounts itself once a column mapping is known).
/// Blank trailing rows (e.g. a trailing newline) are dropped.
List<List<String>> parseCsv(String contents) {
  final rows = const CsvToListConverter(shouldParseNumbers: false)
      .convert<dynamic>(contents);
  return [
    for (final row in rows)
      if (row.any((cell) => cell.toString().trim().isNotEmpty))
        [for (final cell in row) cell?.toString() ?? ''],
  ];
}

String writeCsv(List<List<String>> rows) {
  return const ListToCsvConverter().convert(rows);
}
