import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/auth_controller.dart';
import '../../../core/sync/sync_models.dart';
import '../../../core/sync/sync_providers.dart';
import '../../backup_restore/presentation/backup_export_action.dart';
import '../../backup_restore/presentation/restore_screen.dart';
import '../../categories/presentation/manage_categories_screen.dart';
import '../../import_export/presentation/export_action.dart';
import '../../import_export/presentation/import_wizard_screen.dart';
import '../../lock/presentation/change_pin_sheet.dart';
import 'backend_connection_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(authControllerProvider);
    final sync = ref.watch(syncControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Data'),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text('Manage Categories'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ManageCategoriesScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.upload_file_outlined),
            title: const Text('Export to CSV'),
            subtitle: const Text('Share your full transaction history as a .csv file.'),
            onTap: () => exportTransactionsToCsv(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Import from CSV'),
            subtitle: const Text('Bring in transactions from another app.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ImportWizardScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Back up all data'),
            subtitle: const Text(
              'Save every account, category, transaction, and budget to a file.',
            ),
            onTap: () => backupAllData(context, ref),
          ),
          ListTile(
            leading: const Icon(Icons.restore_outlined),
            title: const Text('Restore from backup'),
            subtitle: const Text('Replace all current data from a backup file.'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RestoreScreen()),
            ),
          ),
          const _SectionHeader('Security'),
          ListTile(
            leading: const Icon(Icons.fingerprint),
            title: const Text('PIN & biometric lock'),
            subtitle: const Text('Active — required every time the app opens.'),
            trailing: TextButton(
              onPressed: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => const ChangePinSheet(),
              ),
              child: const Text('Change PIN'),
            ),
          ),
          const _SectionHeader('Backend & Sync'),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text('Backend & Sync'),
            subtitle: Text(_connectionSubtitle(connection)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BackendConnectionScreen()),
            ),
          ),
          ListTile(
            leading: sync.progress.phase == SyncPhase.syncing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: Padding(
                      padding: EdgeInsets.all(2),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : Icon(
                    sync.progress.phase == SyncPhase.error
                        ? Icons.sync_problem_outlined
                        : Icons.sync_outlined,
                    color: sync.progress.phase == SyncPhase.error
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
            title: const Text('Data sync'),
            subtitle: Text(_syncSubtitle(connection, sync.progress)),
            trailing: connection.phase == ConnectionPhase.loggedIn &&
                    sync.progress.phase != SyncPhase.syncing
                ? TextButton(
                    onPressed: () => sync.syncNow(),
                    child: const Text('Sync now'),
                  )
                : null,
            onTap: connection.phase == ConnectionPhase.loggedIn &&
                    sync.progress.phase != SyncPhase.syncing
                ? () => sync.syncNow()
                : null,
          ),
          const _SectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Money Manager'),
            subtitle: Text('Private, offline-first, no ads or tracking.'),
          ),
        ],
      ),
    );
  }

  String _connectionSubtitle(AuthController connection) {
    return switch (connection.phase) {
      ConnectionPhase.checking => 'Checking…',
      ConnectionPhase.disconnected => 'Not connected',
      ConnectionPhase.connectedLoggedOut => 'Connected — not logged in',
      ConnectionPhase.loggedIn => 'Logged in as ${connection.userEmail}',
    };
  }

  String _syncSubtitle(AuthController connection, SyncProgress progress) {
    if (connection.phase != ConnectionPhase.loggedIn) {
      return 'Log in under Backend & Sync to enable';
    }
    switch (progress.phase) {
      case SyncPhase.syncing:
        return progress.total > 0
            ? 'Syncing ${progress.current}/${progress.total}…'
            : 'Syncing…';
      case SyncPhase.error:
        final reason = progress.lastError;
        return reason == null ? 'Sync error — tap to retry' : 'Sync error: $reason';
      case SyncPhase.idle:
        final lastSyncedAt = progress.lastSyncedAt;
        return lastSyncedAt == null
            ? 'Not synced yet — tap to sync'
            : 'Synced ${_relativeTime(lastSyncedAt)}';
    }
  }

  String _relativeTime(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}
