import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../application/account_providers.dart';

/// Mobile-only screen — the web viewer never navigates here (see
/// AccountsScreen.readOnly, which hides the entry point).
class ArchivedAccountsScreen extends ConsumerWidget {
  const ArchivedAccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archivedAsync = ref.watch(archivedAccountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Archived accounts')),
      body: archivedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
        data: (accounts) {
          if (accounts.isEmpty) {
            return const Center(child: Text('No archived accounts.'));
          }
          return ListView.builder(
            itemCount: accounts.length,
            itemBuilder: (context, index) => _ArchivedAccountTile(account: accounts[index]),
          );
        },
      ),
    );
  }
}

class _ArchivedAccountTile extends ConsumerWidget {
  const _ArchivedAccountTile({required this.account});

  final Account account;

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Delete "${account.name}"?',
      message:
          'This account will be permanently removed from your account list. '
          'Existing transactions will no longer show its name.',
    );
    if (confirmed) {
      await ref.read(accountWriterProvider).deleteAccount(account.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.archive_outlined)),
      title: Text(account.name),
      subtitle: Text(account.type),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () => ref.read(accountWriterProvider).setArchived(account.id, false),
            child: const Text('Unarchive'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: () => _delete(context, ref),
          ),
        ],
      ),
    );
  }
}
