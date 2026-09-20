import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../application/import_wizard_controller.dart';
import '../../data/date_format_detector.dart';
import '../widgets/mapping_dropdown_row.dart';

class StepColumnMapping extends ConsumerWidget {
  const StepColumnMapping({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importWizardControllerProvider);
    final controller = ref.read(importWizardControllerProvider.notifier);
    final sampleRow = state.dataRows.isNotEmpty ? state.dataRows.first : const <String>[];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Match each column to what it represents. Columns that stay '
          "'Ignore' are skipped.",
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const Divider(height: 24),
        for (var i = 0; i < state.headers.length; i++)
          MappingDropdownRow(
            header: state.headers[i],
            sampleValue: i < sampleRow.length ? sampleRow[i] : '',
            value: state.fieldMapping[i],
            onChanged: (field) => controller.setColumnField(i, field),
          ),
        const Divider(height: 24),
        Text('Date format', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: state.dateFormatPattern,
          decoration: const InputDecoration(labelText: 'Date format'),
          items: [
            for (final pattern in candidateDateFormats)
              DropdownMenuItem(value: pattern, child: Text(pattern)),
          ],
          onChanged: (pattern) {
            if (pattern != null) controller.setDateFormatPattern(pattern);
          },
        ),
        if (state.dateFormatAmbiguous) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Date format couldn't be determined with confidence — "
                  'double-check it against the samples below.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                ),
                if (state.dateSampleParses.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Parsed as: ${state.dateSampleParses.map((d) => DateFormat.yMMMd().format(d)).join(', ')}',
                    style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}
