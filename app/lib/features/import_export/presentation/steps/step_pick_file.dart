import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/import_wizard_controller.dart';
import '../../data/csv_codec.dart';
import '../../data/csv_file_io.dart';
import '../widgets/csv_preview_table.dart';

class StepPickFile extends ConsumerStatefulWidget {
  const StepPickFile({super.key});

  @override
  ConsumerState<StepPickFile> createState() => _StepPickFileState();
}

class _StepPickFileState extends ConsumerState<StepPickFile> {
  bool _loading = false;
  String? _error;

  Future<void> _pick() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final picked = await pickCsvFile();
      if (picked == null) {
        setState(() => _loading = false);
        return;
      }
      final (fileName, contents) = picked;
      final rows = parseCsv(contents);
      if (rows.length < 2) {
        setState(() {
          _loading = false;
          _error = 'This file has no data rows to import.';
        });
        return;
      }
      ref.read(importWizardControllerProvider.notifier).loadFile(fileName, rows);
    } catch (e) {
      setState(() => _error = 'Could not read that file: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(importWizardControllerProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Pick a CSV file exported from another money app — or a previous '
            "Money Manager export. You'll be able to review and adjust how "
            'its columns are read before anything is imported.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _loading ? null : _pick,
            icon: const Icon(Icons.file_open_outlined),
            label: Text(state.hasFile ? 'Choose a different file' : 'Choose file'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          if (state.hasFile) ...[
            const SizedBox(height: 24),
            Text(
              '${state.fileName} — ${state.dataRows.length} rows found',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: CsvPreviewTable(
                headers: state.headers,
                rows: state.dataRows.take(5).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
