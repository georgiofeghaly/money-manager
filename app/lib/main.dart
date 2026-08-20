import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_shell.dart';
import 'core/theme/app_theme.dart';
import 'features/lock/presentation/lock_gate.dart';

void main() {
  runApp(const ProviderScope(child: MoneyManagerApp()));
}

class MoneyManagerApp extends StatelessWidget {
  const MoneyManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Money Manager',
      theme: buildLightTheme(),
      darkTheme: buildDarkTheme(),
      themeMode: ThemeMode.system,
      home: const LockGate(child: AppShell()),
    );
  }
}
