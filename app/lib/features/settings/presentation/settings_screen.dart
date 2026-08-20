import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/auth_controller.dart';
import '../../../core/sync/sync_providers.dart';
import '../../categories/presentation/manage_categories_screen.dart';
import '../../lock/presentation/change_pin_sheet.dart';
import 'backend_connection_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(authControllerProvider);

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
          const _SectionHeader('Coming soon'),
          const ListTile(
            enabled: false,
            leading: Icon(Icons.sync_outlined),
            title: Text('Automatic data sync'),
            subtitle: Text('Login works; syncing accounts/transactions is next.'),
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
