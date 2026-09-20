import 'dart:async';

import 'package:flutter/foundation.dart' hide Category;

import '../../core/db/database.dart';
import '../../core/sync/api_client.dart';

/// Read-only data source for the web viewer: hydrates the whole account by
/// paging through the existing `/sync/pull` endpoint from the beginning of
/// time (there's no separate "list my data" REST API — the sync endpoint
/// already returns every row in the exact shape needed). No local storage,
/// no push, no cursor persistence — a fresh full pull on every [load], since
/// the web app has no local database to keep a cursor for (see PRD.md's web
/// app decision: view-only, no local storage/sync).
class WebDataStore extends ChangeNotifier {
  WebDataStore(this._api) {
    addListener(() => _changes.add(null));
  }

  final ApiClient _api;
  final _changes = StreamController<void>.broadcast();

  /// Fires after every [load]/[refresh], successful or not — lets the
  /// Api*Repository readers re-derive their watch streams the same way a
  /// Drift `.watch()` query would re-emit after a DB write.
  Stream<void> get changes => _changes.stream;

  @override
  void dispose() {
    _changes.close();
    super.dispose();
  }

  List<Account> _accounts = const [];
  List<Category> _categories = const [];
  List<Transaction> _transactions = const [];
  List<Budget> _budgets = const [];

  bool _loading = false;
  bool _loaded = false;
  String? _error;

  List<Account> get accounts => _accounts;
  List<Category> get categories => _categories;
  List<Transaction> get transactions => _transactions;
  List<Budget> get budgets => _budgets;

  bool get isLoading => _loading;
  bool get isLoaded => _loaded;
  String? get error => _error;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final accounts = <String, Account>{};
      final categories = <String, Category>{};
      final transactions = <String, Transaction>{};
      final budgets = <String, Budget>{};

      var since = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true).toIso8601String();
      var cursorId = '';

      while (true) {
        final response = await _api.pullSync(since: since, cursorId: cursorId);
        final tables = response['tables'] as Map<String, dynamic>;

        for (final json in _list(tables['accounts'])) {
          final row = accountFromJson(json);
          accounts[row.id] = row;
        }
        for (final json in _list(tables['categories'])) {
          final row = categoryFromJson(json);
          categories[row.id] = row;
        }
        for (final json in _list(tables['transactions'])) {
          final row = transactionFromJson(json);
          transactions[row.id] = row;
        }
        for (final json in _list(tables['budgets'])) {
          final row = budgetFromJson(json);
          budgets[row.id] = row;
        }

        final nextCursor = response['nextCursor'] as Map<String, dynamic>?;
        if (nextCursor == null) break;
        since = nextCursor['since'] as String;
        cursorId = nextCursor['cursorId'] as String;
      }

      _accounts = accounts.values.toList();
      _categories = categories.values.toList();
      _transactions = transactions.values.toList();
      _budgets = budgets.values.toList();
      _loaded = true;
    } on ApiException catch (e) {
      _error = e.message;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() => load();
}

List<Map<String, dynamic>> _list(Object? value) =>
    (value as List? ?? const []).cast<Map<String, dynamic>>();

DateTime? _parseNullableDate(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

@visibleForTesting
Account accountFromJson(Map<String, dynamic> json) => Account(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      type: json['type'] as String,
      startingBalance: (json['startingBalance'] as num).toDouble(),
      archivedAt: _parseNullableDate(json['archivedAt']),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      version: json['version'] as int,
      originDeviceId: json['originDeviceId'] as String?,
      deletedAt: _parseNullableDate(json['deletedAt']),
      syncStatus: 'synced',
    );

@visibleForTesting
Category categoryFromJson(Map<String, dynamic> json) => Category(
      id: json['id'] as String,
      userId: json['userId'] as String?,
      kind: json['kind'] as String,
      name: json['name'] as String,
      icon: json['icon'] as String?,
      color: json['color'] as int?,
      isSeed: false,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      version: json['version'] as int,
      originDeviceId: json['originDeviceId'] as String?,
      deletedAt: _parseNullableDate(json['deletedAt']),
      syncStatus: 'synced',
    );

@visibleForTesting
Transaction transactionFromJson(Map<String, dynamic> json) => Transaction(
      id: json['id'] as String,
      userId: json['userId'] as String,
      type: json['type'] as String,
      amount: (json['amount'] as num).toDouble(),
      occurredAt: DateTime.parse(json['occurredAt'] as String),
      accountId: json['accountId'] as String,
      transferToAccountId: json['transferToAccountId'] as String?,
      categoryId: json['categoryId'] as String?,
      note: json['note'] as String?,
      importBatchId: null,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      version: json['version'] as int,
      originDeviceId: json['originDeviceId'] as String?,
      deletedAt: _parseNullableDate(json['deletedAt']),
      syncStatus: 'synced',
    );

@visibleForTesting
Budget budgetFromJson(Map<String, dynamic> json) => Budget(
      id: json['id'] as String,
      userId: json['userId'] as String,
      categoryId: json['categoryId'] as String,
      periodMonth: DateTime.parse(json['periodMonth'] as String),
      limitAmount: (json['limitAmount'] as num).toDouble(),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      version: json['version'] as int,
      originDeviceId: json['originDeviceId'] as String?,
      deletedAt: _parseNullableDate(json['deletedAt']),
      syncStatus: 'synced',
    );
