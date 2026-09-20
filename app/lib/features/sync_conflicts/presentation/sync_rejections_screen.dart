import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/sync/sync_models.dart';
import '../application/sync_rejection_providers.dart';

/// Lists rows the server refused outright (not a version conflict to
/// resolve — see SyncRejections in core/db/database.dart). There's no
/// resolution action here beyond seeing why: the row stays `pending` and
/// keeps retrying on every sync automatically, so this screen exists purely
/// to answer "did my data actually save, and if not, why".
class SyncRejectionsScreen extends ConsumerWidget {
  const SyncRejectionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rejectionsAsync = ref.watch(syncRejectionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sync issues')),
      body: rejectionsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
        data: (rejections) {
          if (rejections.isEmpty) {
            return const Center(
              child: Text('Nothing stuck — everything has synced.'),
            );
          }
          final grouped = <SyncTableName, List<SyncRejection>>{};
          for (final r in rejections) {
            grouped
                .putIfAbsent(
                  SyncTableName.values.byName(r.syncTableName),
                  () => [],
                )
                .add(r);
          }
          return ListView(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  'These items are saved on this device but the server rejected '
                  'them — they\'ll keep retrying automatically. Tap one for details.',
                ),
              ),
              for (final table in SyncTableName.values)
                if (grouped[table] case final rows? when rows.isNotEmpty) ...[
                  _TableHeader(table),
                  for (final rejection in rows)
                    _RejectionTile(rejection: rejection),
                ],
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader(this.table);
  final SyncTableName table;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        _label(table),
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  String _label(SyncTableName table) => switch (table) {
    SyncTableName.accounts => 'Accounts',
    SyncTableName.categories => 'Categories',
    SyncTableName.transactions => 'Transactions',
    SyncTableName.budgets => 'Budgets',
  };
}

class _RejectionTile extends StatelessWidget {
  const _RejectionTile({required this.rejection});
  final SyncRejection rejection;

  @override
  Widget build(BuildContext context) {
    final local = jsonDecode(rejection.localRowJson) as Map<String, dynamic>;
    return ListTile(
      leading: Icon(
        Icons.error_outline,
        color: Theme.of(context).colorScheme.error,
      ),
      title: Text(_summarize(local)),
      subtitle: Text(
        rejection.reason,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(_summarize(local)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Detected ${_relativeTime(rejection.detectedAt)}'),
                const SizedBox(height: 12),
                Text('Reason', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                SelectableText(rejection.reason),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  String _summarize(Map<String, dynamic> row) {
    if (row.containsKey('name')) return row['name'] as String? ?? '(unnamed)';
    if (row.containsKey('amount')) {
      final note = row['note'] as String?;
      return note != null && note.isNotEmpty ? note : '${row['amount']}';
    }
    return row['id'] as String? ?? 'Unknown row';
  }

  String _relativeTime(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
