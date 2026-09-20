import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/confirm_dialog.dart';
import '../../../categories/application/category_providers.dart';
import '../../application/import_wizard_controller.dart';
import '../../data/import_parser.dart';
import '../widgets/csv_preview_table.dart';

class StepPreviewConfirm extends ConsumerStatefulWidget {
  const StepPreviewConfirm({super.key});

  @override
  ConsumerState<StepPreviewConfirm> createState() => _StepPreviewConfirmState();
}

class _StepPreviewConfirmState extends ConsumerState<StepPreviewConfirm> {
  Future<void> _confirmImport(ImportParseResult result) async {
    final extra = result.pendingCategories.isNotEmpty
        ? ' and ${result.pendingCategories.length} new categories'
        : '';
    final confirmed = await confirmDialog(
      context,
      title: 'Import ${result.rows.length} transactions?',
      message: result.errors.isEmpty
          ? 'This will add ${result.rows.length} transactions$extra.'
          : '${result.rows.length} transactions will be imported$extra. '
              '${result.errors.length} rows will be skipped.',
      confirmLabel: 'Import',
      destructive: false,
    );
    if (!confirmed) return;
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final controller = ref.read(importWizardControllerProvider.notifier);

    final commitResult = await controller.commit();

    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
        content: Text('Imported ${commitResult.importedCount} transactions.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => controller.revert(commitResult.importBatchId),
        ),
        duration: const Duration(seconds: 8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(importWizardControllerProvider);
    final result = state.preview();
    final categoriesAsync = ref.watch(categoriesAllForLookupProvider);

    return Column(
      children: [
        Expanded(
          child: categoriesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, st) => Center(child: Text('Error: $err')),
            data: (categories) {
              final namesById = {for (final c in categories) c.id: c.name};
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _SummaryCard(
                          label: 'Ready to import',
                          value: '${result.rows.length}',
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SummaryCard(
                          label: 'Skipped',
                          value: '${result.errors.length}',
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                  if (result.pendingCategories.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${result.pendingCategories.length} new categories will be created.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (result.errors.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ExpansionTile(
                      title: Text('${result.errors.length} skipped rows'),
                      tilePadding: EdgeInsets.zero,
                      children: [
                        for (final e in result.errors.take(50))
                          ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text('Row ${e.rowIndex + 1}'),
                            subtitle: Text(e.reason),
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text('Preview (first 10 rows)', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  CsvPreviewTable(
                    headers: const ['Date', 'Type', 'Amount', 'Category', 'Note'],
                    rows: [
                      for (final row in result.rows.take(10))
                        [
                          DateFormat.yMMMd().format(row.occurredAt),
                          row.type,
                          row.amount.toStringAsFixed(2),
                          _categoryLabel(row, namesById, result.pendingCategories),
                          row.note ?? '',
                        ],
                    ],
                  ),
                ],
              );
            },
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: state.isCommitting || result.rows.isEmpty
                    ? null
                    : () => _confirmImport(result),
                child: state.isCommitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Import'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _categoryLabel(
    ParsedImportRow row,
    Map<String, String> namesById,
    Map<String, PendingCategory> pendingCategories,
  ) {
    if (row.categoryId != null) return namesById[row.categoryId] ?? '';
    if (row.pendingCategoryKey != null) {
      return '${pendingCategories[row.pendingCategoryKey]!.name} (new)';
    }
    return '';
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: color)),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
