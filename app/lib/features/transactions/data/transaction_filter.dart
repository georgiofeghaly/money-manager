import 'package:collection/collection.dart';

const _setEquality = SetEquality<String>();

/// Search/filter criteria for `TransactionRepository.watchTransactionsFiltered`.
/// Doubles as a `StreamProvider.family` key, hence the hand-written
/// `==`/`hashCode` (mirrors `DateRange` in transaction_providers.dart) —
/// `Set` has identity equality by default, so two filters built from
/// different `Set` instances with the same members must still compare equal.
class TransactionFilter {
  const TransactionFilter({
    this.text,
    this.type,
    this.accountIds = const {},
    this.categoryIds = const {},
    this.start,
    this.end,
    this.minAmount,
    this.maxAmount,
  });

  /// Free-text query, matched against note/account name/category name.
  final String? text;

  /// 'income' | 'expense' | 'transfer' | null (any).
  final String? type;

  /// Empty = any account. Matches either the source or destination account
  /// (for transfers) — see `watchTransactionsFiltered`.
  final Set<String> accountIds;

  /// Empty = any category.
  final Set<String> categoryIds;

  /// Inclusive.
  final DateTime? start;

  /// Exclusive.
  final DateTime? end;

  final double? minAmount;
  final double? maxAmount;

  bool get isEmpty =>
      (text == null || text!.trim().isEmpty) &&
      type == null &&
      accountIds.isEmpty &&
      categoryIds.isEmpty &&
      start == null &&
      end == null &&
      minAmount == null &&
      maxAmount == null;

  TransactionFilter copyWith({
    String? text,
    bool clearText = false,
    String? type,
    bool clearType = false,
    Set<String>? accountIds,
    Set<String>? categoryIds,
    DateTime? start,
    bool clearStart = false,
    DateTime? end,
    bool clearEnd = false,
    double? minAmount,
    bool clearMinAmount = false,
    double? maxAmount,
    bool clearMaxAmount = false,
  }) {
    return TransactionFilter(
      text: clearText ? null : (text ?? this.text),
      type: clearType ? null : (type ?? this.type),
      accountIds: accountIds ?? this.accountIds,
      categoryIds: categoryIds ?? this.categoryIds,
      start: clearStart ? null : (start ?? this.start),
      end: clearEnd ? null : (end ?? this.end),
      minAmount: clearMinAmount ? null : (minAmount ?? this.minAmount),
      maxAmount: clearMaxAmount ? null : (maxAmount ?? this.maxAmount),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is TransactionFilter &&
      other.text == text &&
      other.type == type &&
      _setEquality.equals(other.accountIds, accountIds) &&
      _setEquality.equals(other.categoryIds, categoryIds) &&
      other.start == start &&
      other.end == end &&
      other.minAmount == minAmount &&
      other.maxAmount == maxAmount;

  @override
  int get hashCode => Object.hash(
        text,
        type,
        _setEquality.hash(accountIds),
        _setEquality.hash(categoryIds),
        start,
        end,
        minAmount,
        maxAmount,
      );
}
