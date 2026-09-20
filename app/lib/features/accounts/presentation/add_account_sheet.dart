import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../application/account_providers.dart';

/// Pass [existing] to edit an account in place; omit it to create a new one.
class AddAccountSheet extends ConsumerStatefulWidget {
  const AddAccountSheet({super.key, this.existing});

  final Account? existing;

  @override
  ConsumerState<AddAccountSheet> createState() => _AddAccountSheetState();
}

class _AddAccountSheetState extends ConsumerState<AddAccountSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late final _startingBalanceController = TextEditingController(
    text: (widget.existing?.startingBalance ?? 0).toString(),
  );
  late String _type = widget.existing?.type ?? 'cash';

  static const _types = ['card', 'cash', 'savings', 'custom'];

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _nameController.dispose();
    _startingBalanceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameController.text.trim();
    final startingBalance = double.tryParse(_startingBalanceController.text) ?? 0;
    final repo = ref.read(accountWriterProvider);

    if (_isEditing) {
      await repo.updateAccount(
        id: widget.existing!.id,
        name: name,
        type: _type,
        startingBalance: startingBalance,
      );
    } else {
      await repo.createAccount(
        name: name,
        type: _type,
        startingBalance: startingBalance,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _archive() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Archive account?',
      message:
          '"${widget.existing!.name}" will be hidden from your account list. '
          'Existing transactions will keep referencing it.',
      confirmLabel: 'Archive',
    );
    if (!confirmed) return;
    await ref.read(accountWriterProvider).setArchived(widget.existing!.id, true);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? 'Edit account' : 'New account',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type'),
              items: _types
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _startingBalanceController,
              decoration: const InputDecoration(labelText: 'Starting balance'),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submit,
              child: Text(_isEditing ? 'Save' : 'Create'),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: _archive,
                child: const Text('Archive'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
