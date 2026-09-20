import 'package:flutter/material.dart';

import '../../data/column_mapper.dart';

const importFieldLabels = {
  ImportField.date: 'Date',
  ImportField.amount: 'Amount',
  ImportField.debit: 'Debit',
  ImportField.credit: 'Credit',
  ImportField.type: 'Type',
  ImportField.category: 'Category',
  ImportField.note: 'Note',
};

/// One CSV header + a sample value + a dropdown to pick which transaction
/// field it maps to (or "Ignore").
class MappingDropdownRow extends StatelessWidget {
  const MappingDropdownRow({
    super.key,
    required this.header,
    required this.sampleValue,
    required this.value,
    required this.onChanged,
  });

  final String header;
  final String sampleValue;
  final ImportField? value;
  final ValueChanged<ImportField?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  header,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  sampleValue.isEmpty ? '(blank)' : sampleValue,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<ImportField?>(
              initialValue: value,
              decoration:
                  const InputDecoration(labelText: 'Maps to', isDense: true),
              items: [
                const DropdownMenuItem(value: null, child: Text('Ignore')),
                for (final field in ImportField.values)
                  DropdownMenuItem(value: field, child: Text(importFieldLabels[field]!)),
              ],
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}
