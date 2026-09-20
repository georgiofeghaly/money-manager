import 'package:collection/collection.dart';

import '../../../core/db/database.dart';

/// Client-side text match against note, resolved account name, and resolved
/// category name (SQL `LIKE` can only reach [Transaction.note] — names live
/// in other tables). Case-insensitive substring match; empty/null [text]
/// returns [rows] unchanged.
List<Transaction> applyTextSearch(
  List<Transaction> rows,
  String? text,
  List<Account> accounts,
  List<Category> categories,
) {
  final needle = text?.trim().toLowerCase();
  if (needle == null || needle.isEmpty) return rows;

  return rows.where((t) {
    if ((t.note ?? '').toLowerCase().contains(needle)) return true;
    final accountName =
        accounts.firstWhereOrNull((a) => a.id == t.accountId)?.name ?? '';
    if (accountName.toLowerCase().contains(needle)) return true;
    final transferToName = t.transferToAccountId == null
        ? ''
        : accounts.firstWhereOrNull((a) => a.id == t.transferToAccountId)?.name ?? '';
    if (transferToName.toLowerCase().contains(needle)) return true;
    final categoryName =
        categories.firstWhereOrNull((c) => c.id == t.categoryId)?.name ?? '';
    return categoryName.toLowerCase().contains(needle);
  }).toList();
}
