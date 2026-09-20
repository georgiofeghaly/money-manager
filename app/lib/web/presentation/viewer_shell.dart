import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/sync_providers.dart';
import '../../features/accounts/presentation/accounts_screen.dart';
import '../../features/budgets/presentation/budgets_screen.dart';
import '../../features/calendar/presentation/calendar_screen.dart';
import '../../features/charts/presentation/charts_screen.dart';
import '../data/web_data_providers.dart';

/// Read-only analogue of core/app_shell.dart for the web viewer: same four
/// data tabs (Settings and the sync/backup/import tabs are mobile-only —
/// there's no local database on web to back them), every screen given
/// `readOnly: true` so FABs/tap-to-edit/swipe actions don't render.
class ViewerShell extends ConsumerStatefulWidget {
  const ViewerShell({super.key});

  @override
  ConsumerState<ViewerShell> createState() => _ViewerShellState();
}

class _ViewerShellState extends ConsumerState<ViewerShell> {
  int _index = 0;

  static const _titles = ['Calendar', 'Budgets', 'Charts', 'Accounts'];

  @override
  void initState() {
    super.initState();
    // Kicks off the initial full pull; ViewerRouter only reaches this
    // screen once logged in, but the store itself starts empty.
    Future.microtask(() => ref.read(webDataStoreProvider).load());
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(webDataStoreProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_index]),
        actions: [
          IconButton(
            icon: store.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: store.isLoading ? null : () => store.refresh(),
          ),
          PopupMenuButton<void>(
            icon: const Icon(Icons.account_circle_outlined),
            itemBuilder: (context) => [
              PopupMenuItem(
                enabled: false,
                child: Text(ref.read(authControllerProvider).userEmail ?? ''),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                child: const Text('Log out'),
                onTap: () => ref.read(authControllerProvider).logout(),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (store.isLoading && !store.isLoaded) const LinearProgressIndicator(minHeight: 2),
          if (store.error != null)
            MaterialBanner(
              content: Text('Couldn\'t load data: ${store.error}'),
              leading: const Icon(Icons.error_outline),
              actions: [
                TextButton(onPressed: () => store.refresh(), child: const Text('Retry')),
              ],
            ),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: const [
                CalendarScreen(readOnly: true),
                BudgetsScreen(readOnly: true),
                ChartsScreen(),
                AccountsScreen(readOnly: true),
              ],
            ),
          ),
        ],
      ),
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
        ],
      ),
    );
  }
}
