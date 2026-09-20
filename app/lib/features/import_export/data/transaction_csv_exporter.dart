import 'package:intl/intl.dart';

import '../../../core/db/database.dart';
import 'csv_codec.dart';

const csvExportHeader = [
  'Date',
  'Type',
  'Amount',
  'Account',
  'Transfer To Account',
  'Category',
  'Note',
];

final _exportDateFormat = DateFormat('yyyy-MM-dd');

/// Builds the full export CSV. [accountNamesById]/[categoryNamesById] should
/// come from the "for lookup" providers (include archived/soft-deleted rows)
/// so historical transactions still resolve a name.
String exportTransactionsCsv({
  required List<Transaction> transactions,
  required Map<String, String> accountNamesById,
  required Map<String, String> categoryNamesById,
}) {
  final rows = <List<String>>[
    csvExportHeader,
    for (final t in transactions)
      [
        _exportDateFormat.format(t.occurredAt),
        t.type,
        t.amount.toString(),
        accountNamesById[t.accountId] ?? '',
        t.transferToAccountId != null
            ? (accountNamesById[t.transferToAccountId] ?? '')
            : '',
        t.categoryId != null ? (categoryNamesById[t.categoryId] ?? '') : '',
        t.note ?? '',
      ],
  ];
  return writeCsv(rows);
}
