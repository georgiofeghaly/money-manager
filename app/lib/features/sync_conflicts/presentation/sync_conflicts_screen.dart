import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/sync/sync_models.dart';
import '../application/sync_conflict_providers.dart';
import 'conflict_diff_screen.dart';

class SyncConflictsScreen extends ConsumerWidget {
  const SyncConflictsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conflictsAsync = ref.watch(openSyncConflictsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sync conflicts')),
      body: conflictsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
        data: (conflicts) {
          if (conflicts.isEmpty) {
            return const Center(child: Text('No conflicts to resolve.'));
          }
          final grouped = <SyncTableName, List<SyncConflict>>{};
          for (final c in conflicts) {
            grouped.putIfAbsent(SyncTableName.values.byName(c.syncTableName), () => []).add(c);
          }
          return ListView(
            children: [
              for (final table in SyncTableName.values)
                if (grouped[table] case final rows? when rows.isNotEmpty) ...[
                  _TableHeader(table),
                  for (final conflict in rows) _ConflictTile(conflict: conflict),
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
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
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

class _ConflictTile extends ConsumerWidget {
  const _ConflictTile({required this.conflict});
  final SyncConflict conflict;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(syncConflictRepositoryProvider);
    final local = repo.localRow(conflict);
    return ListTile(
      leading: const Icon(Icons.sync_problem_outlined),
      title: Text(_summarize(local)),
      subtitle: Text('Detected ${_relativeTime(conflict.detectedAt)}'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ConflictDiffScreen(conflict: conflict)),
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
