/// A parsed-but-not-yet-committed transaction, produced by [import_parser]
/// and handed to `TransactionRepository.importTransactions` on confirm.
class TransactionDraft {
  const TransactionDraft({
    required this.type,
    required this.amount,
    required this.occurredAt,
    required this.accountId,
    this.transferToAccountId,
    this.categoryId,
    this.note,
  });

  /// 'income' | 'expense' | 'transfer'
  final String type;
  final double amount;
  final DateTime occurredAt;
  final String accountId;
  final String? transferToAccountId;
  final String? categoryId;
  final String? note;
}
