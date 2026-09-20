import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/auth_controller.dart';
import '../../../core/sync/sync_providers.dart';
import '../application/lock_controller.dart';
import '../application/lock_providers.dart';
import 'lock_screen.dart';
import 'pin_setup_screen.dart';

/// Wraps the whole app: shows PIN setup on first run, the lock screen
/// whenever [LockController] says so (including on re-resume after being
/// backgrounded past the grace period), and [child] once unlocked.
class LockGate extends ConsumerStatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LockGate> createState() => _LockGateState();
}

class _LockGateState extends ConsumerState<LockGate> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = ref.read(lockControllerProvider);
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
        controller.onAppPaused();
      case AppLifecycleState.resumed:
        controller.onAppResumed();
        // Piggybacks on this observer rather than registering a second one
        // (see app/DESIGN.md — LockGate is the app's one lifecycle
        // observer). Only meaningful once logged in.
        if (ref.read(authControllerProvider).phase == ConnectionPhase.loggedIn) {
          unawaited(ref.read(syncControllerProvider).syncOnResume());
        }
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final phase = ref.watch(lockControllerProvider).phase;
    return switch (phase) {
      LockPhase.checking =>
        const Scaffold(body: Center(child: CircularProgressIndicator())),
      LockPhase.needsSetup => const PinSetupScreen(),
      LockPhase.locked => const LockScreen(),
      LockPhase.unlocked => widget.child,
    };
  }
}
