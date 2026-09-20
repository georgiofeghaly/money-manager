import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/sync/auth_controller.dart';
import '../core/sync/sync_providers.dart';
import '../core/theme/app_theme.dart';
import 'admin/presentation/admin_gate.dart';
import 'presentation/login_screen.dart';
import 'presentation/viewer_shell.dart';

/// The web app's routing table. Rebuilt whenever [AuthController] notifies
/// (login/logout/disconnect) — cheap enough with only three routes that
/// recreating the router is simpler than threading a redirect-only update
/// through it.
final goRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);

  return GoRouter(
    refreshListenable: auth,
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const ViewerShell()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      // AdminGate does its own isAdmin check (via GET /auth/me) independent
      // of this redirect — see web/admin/presentation/admin_gate.dart.
      GoRoute(path: '/admin', builder: (context, state) => const AdminGate()),
    ],
    redirect: (context, state) {
      final loggedIn = auth.phase == ConnectionPhase.loggedIn;
      final onLogin = state.matchedLocation == '/login';
      final onAdmin = state.matchedLocation == '/admin';

      if (!loggedIn) return onLogin ? null : '/login';
      if (onLogin) return '/';
      if (onAdmin) return null; // AdminGate handles its own auth UI
      return null;
    },
  );
});

class WebApp extends ConsumerWidget {
  const WebApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      title: 'Money Manager',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
