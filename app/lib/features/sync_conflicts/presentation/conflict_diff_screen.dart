import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/sync/sync_models.dart';
import '../../accounts/presentation/add_account_sheet.dart';
import '../../budgets/presentation/budget_form_sheet.dart';
import '../../categories/presentation/category_form_sheet.dart';
import '../../transactions/presentation/add_transaction_screen.dart';
import '../application/sync_conflict_providers.dart';

/// Side-by-side "Your version" vs "Other version" for one conflict, with
/// the three resolution actions from the PRD's sync design: Keep mine,
/// Keep other, Edit manually. All three ultimately just write a row with a
/// corrected `version` and `syncStatus = 'pending'` — see
/// SyncConflictRepository — so there's no bespoke conflict-resolution
/// endpoint on the backend.
class ConflictDiffScreen extends ConsumerWidget {
  const ConflictDiffScreen({super.key, required this.conflict});
  final SyncConflict conflict;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(syncConflictRepositoryProvider);
    final table = repo.tableOf(conflict);
    final local = repo.localRow(conflict);
    final server = repo.serverRow(conflict);
    final devicesAsync = ref.watch(devicesForLookupProvider);

    String deviceLabel(Object? deviceId) {
      if (deviceId == null) return 'this device';
      final devices = devicesAsync.valueOrNull;
      if (devices == null) return 'device ${(deviceId as String).substring(0, 8)}';
      final match = devices.where((d) => d['id'] == deviceId).firstOrNull;
      final name = match?['deviceName'] as String?;
      return name ?? 'device ${(deviceId as String).substring(0, 8)}';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Resolve conflict')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Your version, edited on ${deviceLabel(local['originDeviceId'])}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _DiffCard(row: local, other: server),
          const SizedBox(height: 24),
          Text(
            'Other version, edited on ${deviceLabel(server['originDeviceId'])}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _DiffCard(row: server, other: local),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () async {
              await repo.resolveKeepMine(conflict);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Keep mine'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () async {
              await repo.resolveKeepOther(conflict);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Keep other'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _editManually(context, ref, repo, table),
            child: const Text('Edit manually'),
          ),
        ],
      ),
    );
  }

  Future<void> _editManually(
    BuildContext context,
    WidgetRef ref,
    dynamic repo,
    SyncTableName table,
  ) async {
    await repo.resolveManually(conflict);
    if (!context.mounted) return;
    Navigator.of(context).pop();

    final db = ref.read(databaseProvider);
    switch (table) {
      case SyncTableName.accounts:
        final row = await (db.select(db.accounts)..where((a) => a.id.equals(conflict.rowId)))
            .getSingleOrNull();
        if (row == null || !context.mounted) return;
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => AddAccountSheet(existing: row),
        );
      case SyncTableName.categories:
        final row = await (db.select(db.categories)..where((c) => c.id.equals(conflict.rowId)))
            .getSingleOrNull();
        if (row == null || !context.mounted) return;
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => CategoryFormSheet(existing: row),
        );
      case SyncTableName.transactions:
        final row =
            await (db.select(db.transactions)..where((t) => t.id.equals(conflict.rowId)))
                .getSingleOrNull();
        if (row == null || !context.mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => AddTransactionScreen(existing: row)),
        );
      case SyncTableName.budgets:
        final row = await (db.select(db.budgets)..where((b) => b.id.equals(conflict.rowId)))
            .getSingleOrNull();
        if (row == null || !context.mounted) return;
        final category = await (db.select(db.categories)
              ..where((c) => c.id.equals(row.categoryId)))
            .getSingleOrNull();
        if (!context.mounted) return;
        await showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => BudgetFormSheet(
            month: row.periodMonth,
            existing: row,
            existingCategory: category,
          ),
        );
    }
  }
}

/// Renders every field that differs from [other] in bold, everything else
/// muted — a plain key/value list rather than a per-table typed widget,
/// since this screen only needs to be legible, not pretty.
class _DiffCard extends StatelessWidget {
  const _DiffCard({required this.row, required this.other});
  final Map<String, dynamic> row;
  final Map<String, dynamic> other;

  static const _hiddenKeys = {'id', 'userId', 'originDeviceId', 'version'};

  @override
  Widget build(BuildContext context) {
    final keys = row.keys.where((k) => !_hiddenKeys.contains(k)).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final key in keys)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$key: ',
                        style: const TextStyle(fontWeight: FontWeight.w400),
                      ),
                      TextSpan(
                        text: '${row[key]}',
                        style: TextStyle(
                          fontWeight: row[key] != other[key]
                              ? FontWeight.bold
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
