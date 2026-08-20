import 'package:flutter/material.dart';

/// Fixed icon-key -> IconData map. Categories store the *key* (a plain
/// string), never a raw icon codepoint — codepoints break under Flutter's
/// icon tree-shaking in release builds when constructed dynamically.
const Map<String, IconData> kCategoryIcons = {
  'car': Icons.directions_car,
  'groceries': Icons.shopping_cart,
  'bills': Icons.receipt_long,
  'gift': Icons.card_giftcard,
  'tools': Icons.build,
  'health': Icons.local_hospital,
  'entertainment': Icons.movie,
  'shopping': Icons.shopping_bag,
  'dining': Icons.restaurant,
  'salary': Icons.payments,
  'bonus': Icons.star,
  'freelance': Icons.laptop_mac,
  'home': Icons.home,
  'transport': Icons.directions_bus,
  'education': Icons.school,
  'travel': Icons.flight,
  'subscriptions': Icons.subscriptions,
  'pets': Icons.pets,
  'insurance': Icons.security,
  'other': Icons.category,
};

const String kDefaultCategoryIconKey = 'other';

const List<Color> kCategoryColorPalette = [
  Color(0xFF26A69A), // teal
  Color(0xFFEF5350), // red
  Color(0xFF42A5F5), // blue
  Color(0xFFFFA726), // orange
  Color(0xFFAB47BC), // purple
  Color(0xFF66BB6A), // green
  Color(0xFFFFCA28), // amber
  Color(0xFF8D6E63), // brown
  Color(0xFF26C6DA), // cyan
  Color(0xFFEC407A), // pink
  Color(0xFF7E57C2), // deep purple
  Color(0xFF78909C), // blue grey
];

IconData iconForKey(String? key) =>
    kCategoryIcons[key] ?? kCategoryIcons[kDefaultCategoryIconKey]!;

/// Deterministic fallback so categories created before the color column
/// existed (or with no color set) still render consistently instead of
/// all collapsing to one default color.
Color defaultColorForId(String id) {
  final index = id.hashCode.abs() % kCategoryColorPalette.length;
  return kCategoryColorPalette[index];
}

Color colorFromArgb(int? argb, String fallbackSeedId) {
  if (argb == null) return defaultColorForId(fallbackSeedId);
  return Color(argb);
}
