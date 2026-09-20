import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/application/account_providers.dart';
import '../../categories/application/category_providers.dart';
import '../../transactions/application/transaction_providers.dart';
import '../data/csv_file_io.dart';
import '../data/transaction_csv_exporter.dart';

/// Builds the full-history CSV export and opens the OS share sheet for it.
Future<void> exportTransactionsToCsv(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final transactions = await ref.read(transactionRepositoryProvider).getAllTransactionsOnce();
    final accounts = await ref.read(accountsForLookupProvider.future);
    final categories = await ref.read(categoriesAllForLookupProvider.future);

    final csv = exportTransactionsCsv(
      transactions: transactions,
      accountNamesById: {for (final a in accounts) a.id: a.name},
      categoryNamesById: {for (final c in categories) c.id: c.name},
    );
    await shareCsvExport(csv);
  } catch (e) {
    messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
  }
}
