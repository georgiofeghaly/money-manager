import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/auth_controller.dart';
import '../../../core/sync/sync_providers.dart';
import '../../presentation/login_screen.dart';
import '../application/admin_providers.dart';
import 'admin_shell.dart';

/// Everything /admin needs to be its own secured area, independent of the
/// main viewer: a login prompt when signed out (same credentials, same
/// backend — there's only one account system), then a server-verified
/// isAdmin check via GET /auth/me before rendering anything. isAdmin is
/// never trusted from a token claim (mirrors the backend's own
/// requireAdmin() — see backend/src/middleware/admin-guard.ts) — a
/// logged-in non-admin user hitting /admin sees "access denied", not a
/// silent redirect, so it's clear the account itself lacks permission.
class AdminGate extends ConsumerWidget {
  const AdminGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final phase = ref.watch(authControllerProvider).phase;

    if (phase != ConnectionPhase.loggedIn) {
      return const LoginScreen();
    }

    final meAsync = ref.watch(meProvider);
    return meAsync.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, st) => Scaffold(
        body: Center(child: Text('Could not verify admin access: $err')),
      ),
      data: (me) {
        if (me['isAdmin'] != true) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline,
                      size: 48, color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 12),
                  const Text('This account doesn\'t have admin access.'),
                  const SizedBox(height: 16),
                  OutlinedButton(
                    onPressed: () => ref.read(authControllerProvider).logout(),
                    child: const Text('Log out'),
                  ),
                ],
              ),
            ),
          );
        }
        return const AdminShell();
      },
    );
  }
}
