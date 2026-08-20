import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/theme/category_style.dart';
import '../application/category_providers.dart';
import 'category_form_sheet.dart';

class ManageCategoriesScreen extends ConsumerWidget {
  const ManageCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage Categories')),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(child: Text('Error: $err')),
        data: (categories) {
          final expense = categories.where((c) => c.kind == 'expense').toList();
          final income = categories.where((c) => c.kind == 'income').toList();
          return ListView(
            children: [
              _KindHeader('Expense'),
              for (final c in expense) _CategoryTile(category: c),
              _KindHeader('Income'),
              for (final c in income) _CategoryTile(category: c),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => const CategoryFormSheet(),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _KindHeader extends StatelessWidget {
  const _KindHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({required this.category});
  final Category category;

  @override
  Widget build(BuildContext context) {
    final color = colorFromArgb(category.color, category.id);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color,
        foregroundColor: Colors.white,
        child: Icon(iconForKey(category.icon)),
      ),
      title: Text(category.name),
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => CategoryFormSheet(existing: category),
      ),
    );
  }
}
