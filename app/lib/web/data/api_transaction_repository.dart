import '../../core/db/database.dart';
import '../../features/transactions/data/transaction_filter.dart';
import '../../features/transactions/data/transaction_repository.dart';
import 'watch_derived.dart';
import 'web_data_store.dart';

class ApiTransactionRepository implements TransactionReader {
  ApiTransactionRepository(this._store);

  final WebDataStore _store;

  List<Transaction> _sortedDesc(Iterable<Transaction> rows) =>
      rows.toList()..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

  @override
  Stream<List<Transaction>> watchTransactionsInRange(DateTime start, DateTime end) =>
      watchDerived(
        _store,
        () => _sortedDesc(_store.transactions.where((t) =>
            t.deletedAt == null &&
            !t.occurredAt.isBefore(start) &&
            t.occurredAt.isBefore(end))),
      );

  @override
  Stream<List<Transaction>> watchTransactionsFiltered(TransactionFilter filter) =>
      watchDerived(_store, () {
        var rows = _store.transactions.where((t) => t.deletedAt == null);
        if (filter.type != null) {
          rows = rows.where((t) => t.type == filter.type);
        }
        if (filter.accountIds.isNotEmpty) {
          rows = rows.where((t) =>
              filter.accountIds.contains(t.accountId) ||
              (t.transferToAccountId != null &&
                  filter.accountIds.contains(t.transferToAccountId)));
        }
        if (filter.categoryIds.isNotEmpty) {
          rows = rows.where(
              (t) => t.categoryId != null && filter.categoryIds.contains(t.categoryId));
        }
        if (filter.start != null) {
          rows = rows.where((t) => !t.occurredAt.isBefore(filter.start!));
        }
        if (filter.end != null) {
          rows = rows.where((t) => t.occurredAt.isBefore(filter.end!));
        }
        if (filter.minAmount != null) {
          rows = rows.where((t) => t.amount >= filter.minAmount!);
        }
        if (filter.maxAmount != null) {
          rows = rows.where((t) => t.amount <= filter.maxAmount!);
        }
        return _sortedDesc(rows);
      });

  @override
  Future<List<Transaction>> getAllTransactionsOnce() async {
    final rows = _store.transactions.where((t) => t.deletedAt == null).toList()
      ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return rows;
  }
}
