import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/accounts/presentation/accounts_screen.dart';
import '../features/accounts/presentation/add_account_sheet.dart';
import '../features/budgets/presentation/budgets_screen.dart';
import '../features/calendar/presentation/calendar_screen.dart';
import '../features/charts/presentation/charts_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/sync_conflicts/application/sync_conflict_providers.dart';
import '../features/sync_conflicts/presentation/sync_conflicts_screen.dart';
import '../features/transactions/presentation/add_transaction_screen.dart';
import 'sync/sync_models.dart';
import 'sync/sync_providers.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;

  static const _screens = [
    CalendarScreen(),
    BudgetsScreen(),
    ChartsScreen(),
    AccountsScreen(),
    SettingsScreen(),
  ];

  void _onFabPressed() {
    switch (_index) {
      case 0:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
        );
      case 3:
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => const AddAccountSheet(),
        );
    }
  }

  bool get _showFab => _index == 0 || _index == 3;

  @override
  Widget build(BuildContext context) {
    final isSyncing =
        ref.watch(syncControllerProvider).progress.phase == SyncPhase.syncing;
    final openConflicts = ref.watch(openSyncConflictsProvider).valueOrNull ?? const [];

    return Scaffold(
      body: Column(
        children: [
          // The one place shared by all 5 tabs — each tab has its own
          // AppBar, so there's no single app-wide bar to hang this off.
          if (isSyncing) const LinearProgressIndicator(minHeight: 2),
          if (openConflicts.isNotEmpty)
            MaterialBanner(
              content: Text(
                openConflicts.length == 1
                    ? '1 sync conflict needs your attention'
                    : '${openConflicts.length} sync conflicts need your attention',
              ),
              leading: const Icon(Icons.sync_problem_outlined),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SyncConflictsScreen()),
                  ),
                  child: const Text('Review'),
                ),
              ],
            ),
          Expanded(child: IndexedStack(index: _index, children: _screens)),
        ],
      ),
      floatingActionButton: _showFab
          ? FloatingActionButton(
              onPressed: _onFabPressed,
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_today_outlined),
            selectedIcon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.savings_outlined),
            selectedIcon: Icon(Icons.savings),
            label: 'Budgets',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Charts',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Accounts',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
