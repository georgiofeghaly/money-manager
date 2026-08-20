import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../application/account_providers.dart';
import 'add_account_sheet.dart';

class AccountsScreen extends ConsumerWidget {
  const AccountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      body: accountsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
        data: (accounts) {
          if (accounts.isEmpty) {
            return const Center(
              child: Text('No accounts yet. Tap + to add one.'),
            );
          }
          return ListView.builder(
            itemCount: accounts.length,
            itemBuilder: (context, index) =>
                _AccountTile(account: accounts[index]),
          );
        },
      ),
    );
  }
}

class _AccountTile extends ConsumerWidget {
  const _AccountTile({required this.account});

  final Account account;

  IconData _iconFor(String type) {
    switch (type) {
      case 'card':
        return Icons.credit_card;
      case 'cash':
        return Icons.payments;
      case 'savings':
        return Icons.savings;
      default:
        return Icons.account_balance_wallet;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(accountBalanceProvider(account.id));

    return Dismissible(
      key: ValueKey(account.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        color: Theme.of(context).colorScheme.errorContainer,
        child: Icon(
          Icons.archive_outlined,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      confirmDismiss: (_) => confirmDialog(
        context,
        title: 'Archive account?',
        message:
            '"${account.name}" will be hidden from your account list. '
            'Existing transactions will keep referencing it.',
        confirmLabel: 'Archive',
      ),
      onDismissed: (_) =>
          ref.read(accountRepositoryProvider).setArchived(account.id, true),
      child: ListTile(
        leading: CircleAvatar(child: Icon(_iconFor(account.type))),
        title: Text(account.name),
        subtitle: Text(account.type),
        trailing: balanceAsync.when(
          loading: () => const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          error: (err, st) => const Text('—'),
          data: (balance) => Text(
            balance.toStringAsFixed(2),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: balance < 0
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => AddAccountSheet(existing: account),
        ),
      ),
    );
  }
}
