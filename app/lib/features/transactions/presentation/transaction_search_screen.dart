import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/database.dart';
import '../../accounts/application/account_providers.dart';
import '../../categories/application/category_providers.dart';
import '../application/transaction_providers.dart';
import '../data/transaction_filter.dart';
import 'transaction_tile.dart';

class TransactionSearchScreen extends ConsumerStatefulWidget {
  const TransactionSearchScreen({super.key, this.readOnly = false});

  final bool readOnly;

  @override
  ConsumerState<TransactionSearchScreen> createState() => _TransactionSearchScreenState();
}

class _TransactionSearchScreenState extends ConsumerState<TransactionSearchScreen> {
  final _textController = TextEditingController();
  Timer? _debounce;
  TransactionFilter _filter = const TransactionFilter();

  @override
  void dispose() {
    _debounce?.cancel();
    _textController.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() => _filter = _filter.copyWith(text: value, clearText: value.isEmpty));
    });
  }

  Future<void> _openFilterSheet() async {
    final result = await showModalBottomSheet<TransactionFilter>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(initial: _filter),
    );
    if (result != null) setState(() => _filter = result);
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(accountsForLookupProvider).valueOrNull ?? const [];
    final categories = ref.watch(categoriesAllForLookupProvider).valueOrNull ?? const [];
    final resultsAsync = ref.watch(transactionSearchResultsProvider(_filter));

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _textController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Search transactions…',
            border: InputBorder.none,
            suffixIcon: _textController.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _textController.clear();
                      _onTextChanged('');
                    },
                  ),
          ),
          onChanged: _onTextChanged,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filters',
            onPressed: _openFilterSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_filter.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: _ActiveFilterChips(
                filter: _filter,
                accounts: accounts,
                categories: categories,
                onChanged: (f) => setState(() => _filter = f),
              ),
            ),
          Expanded(
            child: resultsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => Center(child: Text('Error: $err')),
              data: (results) {
                if (results.isEmpty) {
                  return Center(
                    child: Text(
                      _filter.isEmpty
                          ? 'Search by note, category, or account.'
                          : 'No transactions match your filters.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: results.length,
                  itemBuilder: (context, index) {
                    final t = results[index];
                    return TransactionTile(
                      transaction: t,
                      accountName: accounts.firstWhereOrNull((a) => a.id == t.accountId)?.name,
                      transferToAccountName: accounts
                          .firstWhereOrNull((a) => a.id == t.transferToAccountId)
                          ?.name,
                      category: categories.firstWhereOrNull((c) => c.id == t.categoryId),
                      showDate: true,
                      readOnly: widget.readOnly,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveFilterChips extends StatelessWidget {
  const _ActiveFilterChips({
    required this.filter,
    required this.accounts,
    required this.categories,
    required this.onChanged,
  });

  final TransactionFilter filter;
  final List<Account> accounts;
  final List<Category> categories;
  final ValueChanged<TransactionFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (filter.type != null) {
      chips.add(_chip(filter.type!, () => onChanged(filter.copyWith(clearType: true))));
    }
    for (final id in filter.accountIds) {
      final name = accounts.firstWhereOrNull((a) => a.id == id)?.name ?? id;
      chips.add(_chip(name, () {
        onChanged(filter.copyWith(accountIds: {...filter.accountIds}..remove(id)));
      }));
    }
    for (final id in filter.categoryIds) {
      final name = categories.firstWhereOrNull((c) => c.id == id)?.name ?? id;
      chips.add(_chip(name, () {
        onChanged(filter.copyWith(categoryIds: {...filter.categoryIds}..remove(id)));
      }));
    }
    if (filter.start != null || filter.end != null) {
      final start = filter.start != null ? DateFormat.yMMMd().format(filter.start!) : '…';
      final end = filter.end != null
          ? DateFormat.yMMMd().format(filter.end!.subtract(const Duration(days: 1)))
          : '…';
      chips.add(_chip('$start – $end', () {
        onChanged(filter.copyWith(clearStart: true, clearEnd: true));
      }));
    }
    if (filter.minAmount != null || filter.maxAmount != null) {
      final min = filter.minAmount?.toStringAsFixed(0) ?? '0';
      final max = filter.maxAmount?.toStringAsFixed(0) ?? '∞';
      chips.add(_chip('$min–$max', () {
        onChanged(filter.copyWith(clearMinAmount: true, clearMaxAmount: true));
      }));
    }

    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(spacing: 8, runSpacing: 4, children: chips);
  }

  Widget _chip(String label, VoidCallback onDeleted) {
    return Chip(label: Text(label), onDeleted: onDeleted);
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});
  final TransactionFilter initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _type = widget.initial.type;
  late Set<String> _accountIds = {...widget.initial.accountIds};
  late Set<String> _categoryIds = {...widget.initial.categoryIds};
  late DateTime? _start = widget.initial.start;
  late DateTime? _end = widget.initial.end;
  late final _minController =
      TextEditingController(text: widget.initial.minAmount?.toStringAsFixed(2) ?? '');
  late final _maxController =
      TextEditingController(text: widget.initial.maxAmount?.toStringAsFixed(2) ?? '');

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _start != null && _end != null
          ? DateTimeRange(start: _start!, end: _end!.subtract(const Duration(days: 1)))
          : null,
    );
    if (picked != null) {
      setState(() {
        _start = DateTime(picked.start.year, picked.start.month, picked.start.day);
        _end = DateTime(picked.end.year, picked.end.month, picked.end.day)
            .add(const Duration(days: 1));
      });
    }
  }

  void _apply() {
    final min = double.tryParse(_minController.text);
    final max = double.tryParse(_maxController.text);
    Navigator.of(context).pop(
      widget.initial.copyWith(
        type: _type,
        clearType: _type == null,
        accountIds: _accountIds,
        categoryIds: _categoryIds,
        start: _start,
        clearStart: _start == null,
        end: _end,
        clearEnd: _end == null,
        minAmount: min,
        clearMinAmount: min == null,
        maxAmount: max,
        clearMaxAmount: max == null,
      ),
    );
  }

  void _clearAll() {
    setState(() {
      _type = null;
      _accountIds = {};
      _categoryIds = {};
      _start = null;
      _end = null;
      _minController.clear();
      _maxController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final accountsList = ref.watch(accountsForLookupProvider).valueOrNull ?? const [];
        final categoriesList = ref.watch(categoriesAllForLookupProvider).valueOrNull ?? const [];

        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Filters', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                Text('Type', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                SegmentedButton<String?>(
                  segments: const [
                    ButtonSegment(value: null, label: Text('Any')),
                    ButtonSegment(value: 'expense', label: Text('Expense')),
                    ButtonSegment(value: 'income', label: Text('Income')),
                    ButtonSegment(value: 'transfer', label: Text('Transfer')),
                  ],
                  selected: {_type},
                  onSelectionChanged: (selection) => setState(() => _type = selection.first),
                ),
                const SizedBox(height: 16),
                if (accountsList.isNotEmpty) ...[
                  Text('Accounts', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final a in accountsList)
                        FilterChip(
                          label: Text(a.name),
                          selected: _accountIds.contains(a.id),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              _accountIds.add(a.id);
                            } else {
                              _accountIds.remove(a.id);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                if (categoriesList.isNotEmpty) ...[
                  Text('Categories', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final c in categoriesList)
                        FilterChip(
                          label: Text(c.name),
                          selected: _categoryIds.contains(c.id),
                          onSelected: (selected) => setState(() {
                            if (selected) {
                              _categoryIds.add(c.id);
                            } else {
                              _categoryIds.remove(c.id);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                Text('Date range', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _pickDateRange,
                  icon: const Icon(Icons.date_range),
                  label: Text(
                    _start != null && _end != null
                        ? '${DateFormat.yMMMd().format(_start!)} – '
                            '${DateFormat.yMMMd().format(_end!.subtract(const Duration(days: 1)))}'
                        : 'Any date',
                  ),
                ),
                const SizedBox(height: 16),
                Text('Amount range', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _minController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Min'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _maxController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Max'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    TextButton(onPressed: _clearAll, child: const Text('Clear all')),
                    const Spacer(),
                    FilledButton(onPressed: _apply, child: const Text('Apply')),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
