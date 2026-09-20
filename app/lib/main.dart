import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_shell.dart';
import 'core/sync/sync_providers.dart';
import 'core/sync/sync_triggers.dart';
import 'core/theme/app_theme.dart';
import 'features/lock/presentation/lock_gate.dart';

void main() {
  // registerPeriodicSync() below hits a platform channel (Workmanager) before
  // runApp() would otherwise initialize the binding, so it must be done here
  // first or ServicesBinding.instance throws "Binding has not yet been
  // initialized".
  WidgetsFlutterBinding.ensureInitialized();
  // workmanager only has Android/iOS implementations — registering it on
  // desktop/web throws a MissingPluginException, and this app is Android-only
  // for v1 anyway (see PRD.md), but the other platform folders in this repo
  // (windows/linux/macos) mean `flutter run -d windows` etc. must not crash.
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    unawaited(registerPeriodicSync());
  }
  runApp(const ProviderScope(child: MoneyManagerApp()));
}

class MoneyManagerApp

 extends ConsumerWidget {
  const MoneyManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Instantiates the connectivity-regained listener once for the app's
    // lifetime (not autoDispose, so this single read keeps it alive).
    ref.watch(connectivitySyncTriggerProvider);

    return MaterialApp(
      title: 'Money Manager',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      home: const LockGate(child: AppShell()),
    );
  }
}
