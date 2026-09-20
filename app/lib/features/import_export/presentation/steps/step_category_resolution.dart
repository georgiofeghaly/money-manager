import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/db/database.dart';
import '../../../categories/application/category_providers.dart';
import '../../application/import_wizard_controller.dart';
import '../../data/category_matcher.dart';
import '../../data/import_parser.dart';

class StepCategoryResolution extends ConsumerStatefulWidget {
  const StepCategoryResolution({super.key});

  @override
  ConsumerState<StepCategoryResolution> createState() => _StepCategoryResolutionState();
}

class _StepCategoryResolutionState extends ConsumerState<StepCategoryResolution> {
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(importWizardControllerProvider);
    final controller = ref.read(importWizardControllerProvider.notifier);
    final categoriesAsync = ref.watch(categoriesAllForLookupProvider);

    return categoriesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, st) => Center(child: Text('Error: $err')),
      data: (allCategories) {
        final byKind = <String, List<Category>>{};
        for (final c in allCategories) {
          byKind.putIfAbsent(c.kind, () => []).add(c);
        }

        final usages = state.categoryUsages;
        final missing =
            usages.where((u) => !state.categoryResolutions.containsKey(u.rawText)).toList();

        if (missing.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            for (final usage in missing) {
              final candidates = byKind[usage.kind] ?? const [];
              final match = matchCategory(usage.rawText, candidates);
              controller.setCategoryResolution(
                usage.rawText,
                match.suggested != null
                    ? CategoryResolution.useExisting(match.suggested!.id)
                    : CategoryResolution.createNew(usage.rawText),
              );
            }
          });
          return const Center(child: CircularProgressIndicator());
        }

        if (usages.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('No category column was mapped — nothing to resolve here.'),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Each category found in the file needs to map to an existing '
              "category, a new one, or be skipped. We've guessed the closest "
              'match — review and adjust as needed.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            for (final usage in usages)
              _CategoryUsageRow(
                usage: usage,
                candidates: byKind[usage.kind] ?? const [],
                resolution: state.categoryResolutions[usage.rawText]!,
                onChanged: (r) => controller.setCategoryResolution(usage.rawText, r),
              ),
          ],
        );
      },
    );
  }
}

const _createNewSentinel = '__create_new__';
const _skipSentinel = '__skip__';

class _CategoryUsageRow extends StatelessWidget {
  const _CategoryUsageRow({
    required this.usage,
    required this.candidates,
    required this.resolution,
    required this.onChanged,
  });

  final CategoryUsage usage;
  final List<Category> candidates;
  final CategoryResolution resolution;
  final ValueChanged<CategoryResolution> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedValue =
        resolution.skip ? _skipSentinel : (resolution.categoryId ?? _createNewSentinel);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        initialValue: selectedValue,
        decoration: InputDecoration(labelText: '"${usage.rawText}" (${usage.kind})'),
        items: [
          for (final c in candidates) DropdownMenuItem(value: c.id, child: Text(c.name)),
          DropdownMenuItem(
            value: _createNewSentinel,
            child: Text('Create new: "${usage.rawText}"'),
          ),
          const DropdownMenuItem(value: _skipSentinel, child: Text('Skip these rows')),
        ],
        onChanged: (value) {
          if (value == null) return;
          if (value == _createNewSentinel) {
            onChanged(CategoryResolution.createNew(usage.rawText));
          } else if (value == _skipSentinel) {
            onChanged(const CategoryResolution.skip());
          } else {
            onChanged(CategoryResolution.useExisting(value));
          }
        },
      ),
    );
  }
}
