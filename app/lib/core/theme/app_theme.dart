import 'package:flutter/material.dart';

/// Semantic colors for transaction types, used wherever a transaction's
/// type needs a color (calendar list, forms, future charts) so they stay
/// consistent instead of being picked ad hoc per screen.
class TransactionColors {
  const TransactionColors._();

  static const Color income = Color(0xFF2E7D32); // green
  static Color expense(BuildContext context) =>
      Theme.of(context).colorScheme.error;
  static Color transfer(BuildContext context) =>
      Theme.of(context).colorScheme.tertiary;
}

ThemeData buildLightTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
    useMaterial3: true,
  );
}

ThemeData buildDarkTheme() {
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.teal,
      brightness: Brightness.dark,
    ),
    useMaterial3: true,
  );
}
