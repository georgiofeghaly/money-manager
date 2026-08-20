import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/theme/category_style.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../application/category_providers.dart';

/// Pass [existing] to edit a category in place; omit it to create a new one.
class CategoryFormSheet extends ConsumerStatefulWidget {
  const CategoryFormSheet({super.key, this.existing, this.initialKind});

  final Category? existing;
  final String? initialKind;

  @override
  ConsumerState<CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends ConsumerState<CategoryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late String _kind = widget.existing?.kind ?? widget.initialKind ?? 'expense';
  late String _iconKey = widget.existing?.icon ?? kDefaultCategoryIconKey;
  late Color _color = widget.existing != null
      ? colorFromArgb(widget.existing!.color, widget.existing!.id)
      : kCategoryColorPalette.first;

  bool get _isEditing => widget.existing != null;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = ref.read(categoryRepositoryProvider);
    final name = _nameController.text.trim();

    if (_isEditing) {
      await repo.updateCategory(
        id: widget.existing!.id,
        name: name,
        iconKey: _iconKey,
        color: _color,
      );
    } else {
      await repo.createCategory(
        name: name,
        kind: _kind,
        iconKey: _iconKey,
        color: _color,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Delete category?',
      message:
          '"${widget.existing!.name}" will no longer appear when adding '
          'transactions. Existing transactions keep it.',
    );
    if (!confirmed) return;
    await ref.read(categoryRepositoryProvider).deleteCategory(widget.existing!.id);
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
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isEditing ? 'Edit category' : 'New category',
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
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'expense', label: Text('Expense')),
                  ButtonSegment(value: 'income', label: Text('Income')),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
              const SizedBox(height: 16),
              Text('Icon', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kCategoryIcons.entries.map((entry) {
                  final selected = entry.key == _iconKey;
                  return InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () => setState(() => _iconKey = entry.key),
                    child: CircleAvatar(
                      backgroundColor: selected
                          ? _color
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      foregroundColor: selected
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      child: Icon(entry.value),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              Text('Color', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kCategoryColorPalette.map((color) {
                  final selected = color.toARGB32() == _color.toARGB32();
                  return InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => setState(() => _color = color),
                    child: CircleAvatar(
                      backgroundColor: color,
                      radius: selected ? 18 : 16,
                      child: selected
                          ? const Icon(Icons.check, color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
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
                  onPressed: _delete,
                  child: const Text('Delete'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
