import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/db/database_provider.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../application/backup_providers.dart';
import '../data/backup_file_io.dart';
import '../data/backup_payload.dart';

class RestoreScreen extends ConsumerStatefulWidget {
  const RestoreScreen({super.key});

  @override
  ConsumerState<RestoreScreen> createState() => _RestoreScreenState();
}

class _RestoreScreenState extends ConsumerState<RestoreScreen> {
  BackupPayload? _payload;
  String? _error;
  bool _busy = false;

  Future<void> _pick() async {
    setState(() {
      _error = null;
      _payload = null;
    });
    try {
      final picked = await pickBackupFile();
      if (picked == null) return;
      final (_, contents) = picked;
      final payload = BackupPayload.fromJson(
        jsonDecode(contents) as Map<String, dynamic>,
      );
      setState(() => _payload = payload);
    } catch (e) {
      setState(() => _error = 'Not a valid Money Manager backup file.');
    }
  }

  Future<void> _restore(BackupPayload payload) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Replace all data?',
      message:
          'This will permanently delete everything currently in the app '
          '(${payload.accounts.length} accounts, ${payload.categories.length} '
          'categories, ${payload.transactions.length} transactions, '
          '${payload.budgets.length} budgets) and replace it with this backup '
          'from ${DateFormat.yMMMd().add_jm().format(payload.exportedAt)}. '
          'This cannot be undone.',
      confirmLabel: 'Restore',
    );
    if (!confirmed) return;
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(backupRepositoryProvider).restoreAll(payload);
      navigator.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Restore complete.')));
    } catch (e) {
      if (mounted) setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text('Restore failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentSchemaVersion = ref.watch(databaseProvider).schemaVersion;
    final payload = _payload;

    return Scaffold(
      appBar: AppBar(title: const Text('Restore from backup')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pick a Money Manager backup file (.json). Restoring replaces '
              'everything currently in the app.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _pick,
              icon: const Icon(Icons.file_open_outlined),
              label: Text(payload == null ? 'Choose backup file…' : 'Choose a different file'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            if (payload != null) ...[
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Backup from ${DateFormat.yMMMd().add_jm().format(payload.exportedAt)}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${payload.accounts.length} accounts • '
                        '${payload.categories.length} categories • '
                        '${payload.transactions.length} transactions • '
                        '${payload.budgets.length} budgets',
                      ),
                      if (payload.schemaVersion != currentSchemaVersion) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'This backup was made with a different app version and '
                            'may not restore correctly.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'This will permanently delete all current data and replace it '
                'with this backup. This cannot be undone.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _busy ? null : () => _restore(payload),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Restore'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
