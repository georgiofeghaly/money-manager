import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/database.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../accounts/application/account_providers.dart';
import '../../categories/application/category_providers.dart';
import '../application/transaction_providers.dart';

/// Pass [existing] to edit a transaction in place; omit it to create a new one.
class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key, this.existing});

  final Transaction? existing;

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _amountController = TextEditingController(
    text: widget.existing != null ? widget.existing!.amount.toString() : '',
  );
  late final _noteController = TextEditingController(
    text: widget.existing?.note ?? '',
  );

  late String _type = widget.existing?.type ?? 'expense';
  String? _accountId;
  String? _transferToAccountId;
  String? _categoryId;
  late DateTime _occurredAt = widget.existing?.occurredAt ?? DateTime.now();

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _accountId = widget.existing?.accountId;
    _transferToAccountId = widget.existing?.transferToAccountId;
    _categoryId = widget.existing?.categoryId;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _occurredAt = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _occurredAt.hour,
          _occurredAt.minute,
        );
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_accountId == null) return;
    if (_type == 'transfer' && _transferToAccountId == null) return;
    if (_type != 'transfer' && _categoryId == null) return;

    final repo = ref.read(transactionWriterProvider);
    final amount = double.parse(_amountController.text);
    final note =
        _noteController.text.trim().isEmpty ? null : _noteController.text.trim();

    if (_isEditing) {
      await repo.updateTransaction(
        id: widget.existing!.id,
        type: _type,
        amount: amount,
        occurredAt: _occurredAt,
        accountId: _accountId!,
        transferToAccountId: _type == 'transfer' ? _transferToAccountId : null,
        categoryId: _type == 'transfer' ? null : _categoryId,
        note: note,
      );
    } else {
      await repo.createTransaction(
        type: _type,
        amount: amount,
        occurredAt: _occurredAt,
        accountId: _accountId!,
        transferToAccountId: _type == 'transfer' ? _transferToAccountId : null,
        categoryId: _type == 'transfer' ? null : _categoryId,
        note: note,
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Delete transaction?',
      message: 'This can\'t be undone.',
    );
    if (!confirmed) return;
    await ref.read(transactionWriterProvider).deleteTransaction(widget.existing!.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsForLookupProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit transaction' : 'Add transaction'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'expense', label: Text('Expense')),
                  ButtonSegment(value: 'income', label: Text('Income')),
                  ButtonSegment(value: 'transfer', label: Text('Transfer')),
                ],
                selected: {_type},
                onSelectionChanged: (selection) => setState(() {
                  _type = selection.first;
                  _categoryId = null;
                  _transferToAccountId = null;
                }),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Amount'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  final parsed = double.tryParse(v ?? '');
                  if (parsed == null || parsed <= 0) return 'Enter an amount';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              accountsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (err, st) => Text('Error: $err'),
                data: (accounts) {
                  if (accounts.isEmpty) {
                    return const Text(
                      'Create an account first, from the Accounts tab.',
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _accountId,
                        decoration: InputDecoration(
                          labelText:
                              _type == 'transfer' ? 'From account' : 'Account',
                        ),
                        items: accounts
                            .map((a) => DropdownMenuItem(
                                  value: a.id,
                                  child: Text(_accountLabel(a)),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _accountId = v),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      if (_type == 'transfer') ...[
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _transferToAccountId,
                          decoration:
                              const InputDecoration(labelText: 'To account'),
                          items: accounts
                              .where((a) => a.id != _accountId)
                              .map((a) => DropdownMenuItem(
                                    value: a.id,
                                    child: Text(_accountLabel(a)),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _transferToAccountId = v),
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                      ],
                    ],
                  );
                },
              ),
              if (_type != 'transfer') ...[
                const SizedBox(height: 12),
                Consumer(
                  builder: (context, ref, _) {
                    final categoriesAsync =
                        ref.watch(categoriesForLookupByKindProvider(_type));
                    return categoriesAsync.when(
                      loading: () => const LinearProgressIndicator(),
                      error: (err, st) => Text('Error: $err'),
                      data: (categories) => DropdownButtonFormField<String>(
                        initialValue: _categoryId,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        items: categories
                            .map((c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(_categoryLabel(c)),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _categoryId = v),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Date'),
                subtitle: Text(DateFormat.yMMMd().format(_occurredAt)),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submit,
                child: Text(_isEditing ? 'Save' : 'Add'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _accountLabel(Account a) =>
      a.archivedAt != null ? '${a.name} (archived)' : a.name;

  String _categoryLabel(Category c) =>
      c.deletedAt != null ? '${c.name} (deleted)' : c.name;
}
