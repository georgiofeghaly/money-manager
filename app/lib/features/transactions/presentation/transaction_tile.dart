import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/db/database.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/category_style.dart';
import 'add_transaction_screen.dart';

/// Shared transaction row, used by both the Calendar list (grouped under day
/// headers, [showDate] false) and search results (ungrouped, [showDate] true).
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    required this.accountName,
    required this.transferToAccountName,
    required this.category,
    this.showDate = false,
    this.readOnly = false,
  });

  final Transaction transaction;
  final String? accountName;
  final String? transferToAccountName;
  final Category? category;
  final bool showDate;

  /// True on the web viewer — disables tap-to-edit.
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final isTransfer = transaction.type == 'transfer';
    final color = switch (transaction.type) {
      'income' => TransactionColors.income,
      'expense' => TransactionColors.expense(context),
      _ => TransactionColors.transfer(context),
    };
    final icon = isTransfer ? Icons.swap_horiz : iconForKey(category?.icon);
    final avatarColor = isTransfer
        ? color
        : colorFromArgb(category?.color, category?.id ?? transaction.id);
    final sign = switch (transaction.type) {
      'income' => '+',
      'expense' => '-',
      _ => '',
    };

    final title = isTransfer
        ? '$accountName → $transferToAccountName'
        : (category?.name ?? 'Uncategorized');

    final subtitleParts = [
      if (!isTransfer) accountName,
      if (showDate) DateFormat.yMMMd().format(transaction.occurredAt),
      if (transaction.note != null && transaction.note!.isNotEmpty) transaction.note,
    ].whereType<String>();

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: avatarColor,
        foregroundColor: Colors.white,
        child: Icon(icon),
      ),
      title: Text(title),
      subtitle: subtitleParts.isEmpty ? null : Text(subtitleParts.join(' • ')),
      trailing: Text(
        '$sign${transaction.amount.toStringAsFixed(2)}',
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
      onTap: readOnly
          ? null
          : () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AddTransactionScreen(existing: transaction)),
              ),
    );
  }
}
