import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../categories/application/category_providers.dart';
import '../application/budget_providers.dart';

/// Pass [existing] to edit a budget's limit; omit it to create a new one for
/// a category that isn't budgeted yet this month (see [excludedCategoryIds]).
class BudgetFormSheet extends ConsumerStatefulWidget {
  const BudgetFormSheet({
    super.key,
    required this.month,
    this.existing,
    this.existingCategory,
    this.excludedCategoryIds = const {},
  });

  final DateTime month;
  final Budget? existing;
  final Category? existingCategory;
  final Set<String> excludedCategoryIds;

  @override
  ConsumerState<BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends ConsumerState<BudgetFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _limitController = TextEditingController(
    text: widget.existing != null ? widget.existing!.limitAmount.toString() : '',
  );
  String? _categoryId;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.existing?.categoryId;
  }

  @override
  void dispose() {
    _limitController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_categoryId == null) return;
    await ref.read(budgetRepositoryProvider).upsertBudget(
          categoryId: _categoryId!,
          month: widget.month,
          limitAmount: double.parse(_limitController.text),
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final confirmed = await confirmDialog(
      context,
      title: 'Delete budget?',
      message:
          'The budget for "${widget.existingCategory?.name ?? 'this category'}" this month will be removed.',
    );
    if (!confirmed) return;
    await ref.read(budgetRepositoryProvider).deleteBudget(widget.existing!.id);
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
              _isEditing ? 'Edit budget' : 'New budget',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            if (_isEditing)
              Text(
                widget.existingCategory?.name ?? '',
                style: Theme.of(context).textTheme.titleMedium,
              )
            else
              Consumer(
                builder: (context, ref, _) {
                  final categoriesAsync =
                      ref.watch(categoriesByKindProvider('expense'));
                  return categoriesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (err, st) => Text('Error: $err'),
                    data: (categories) {
                      final available = categories
                          .where((c) =>
                              !widget.excludedCategoryIds.contains(c.id))
                          .toList();
                      if (available.isEmpty) {
                        return const Text(
                          'Every expense category already has a budget this month.',
                        );
                      }
                      return DropdownButtonFormField<String>(
                        initialValue: _categoryId,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: available
                            .map((c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.name),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _categoryId = v),
                        validator: (v) => v == null ? 'Required' : null,
                      );
                    },
                  );
                },
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _limitController,
              decoration: const InputDecoration(labelText: 'Monthly limit'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final parsed = double.tryParse(v ?? '');
                if (parsed == null || parsed <= 0) return 'Enter an amount';
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _categoryId == null && !_isEditing ? null : _submit,
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
    );
  }
}
