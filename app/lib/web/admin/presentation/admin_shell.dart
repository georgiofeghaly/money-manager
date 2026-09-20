import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/sync/sync_providers.dart';
import '../application/admin_providers.dart';
import 'create_user_screen.dart';

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(adminUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => ref.invalidate(adminUsersProvider),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => ref.read(authControllerProvider).logout(),
          ),
        ],
      ),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
        data: (users) {
          if (users.isEmpty) {
            return const Center(child: Text('No users yet.'));
          }
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) => _UserTile(user: users[index]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateUserScreen()),
          );
          ref.invalidate(adminUsersProvider);
        },
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('New user'),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user});
  final Map<String, dynamic> user;

  @override
  Widget build(BuildContext context) {
    final isAdmin = user['isAdmin'] == true;
    final isActive = user['isActive'] != false;
    return ListTile(
      leading: CircleAvatar(
        child: Icon(isAdmin ? Icons.admin_panel_settings_outlined : Icons.person_outline),
      ),
      title: Text((user['displayName'] as String?)?.isNotEmpty == true
          ? user['displayName'] as String
          : user['email'] as String),
      subtitle: Text([
        user['email'] as String,
        if (isAdmin) 'Admin',
        if (!isActive) 'Deactivated',
      ].join(' • ')),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _UserDevicesScreen(user: user)),
      ),
    );
  }
}

class _UserDevicesScreen extends ConsumerWidget {
  const _UserDevicesScreen({required this.user});
  final Map<String, dynamic> user;

  String _formatDate(String? iso) {
    if (iso == null) return 'never';
    return DateFormat.yMMMd().add_jm().format(DateTime.parse(iso).toLocal());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = user['id'] as String;
    final devicesAsync = ref.watch(adminUserDevicesProvider(userId));
    final title = (user['displayName'] as String?)?.isNotEmpty == true
        ? user['displayName'] as String
        : user['email'] as String;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: devicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
        data: (devices) {
          if (devices.isEmpty) {
            return const Center(child: Text('No devices have signed in yet.'));
          }
          return ListView.builder(
            itemCount: devices.length,
            itemBuilder: (context, index) {
              final d = devices[index];
              final revoked = d['revokedAt'] != null;
              final syncStatus = d['lastSyncStatus'] as String?;
              return ListTile(
                leading: Icon(
                  revoked ? Icons.phonelink_erase_outlined : Icons.smartphone_outlined,
                  color: revoked ? Theme.of(context).colorScheme.error : null,
                ),
                title: Text(d['deviceName'] as String? ?? 'Unnamed device'),
                subtitle: Text(
                  'Last sign-in: ${_formatDate(d['lastSeenAt'] as String?)}\n'
                  'Last sync: ${_formatDate(d['lastSyncAt'] as String?)}'
                  '${syncStatus != null ? ' ($syncStatus)' : ''}',
                ),
                isThreeLine: true,
                trailing: revoked ? const Text('Revoked') : null,
              );
            },
          );
        },
      ),
    );
  }
}
