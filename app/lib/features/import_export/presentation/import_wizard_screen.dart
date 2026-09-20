import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/import_wizard_controller.dart';
import 'steps/step_account_and_strategy.dart';
import 'steps/step_category_resolution.dart';
import 'steps/step_column_mapping.dart';
import 'steps/step_pick_file.dart';
import 'steps/step_preview_confirm.dart';

const _titles = [
  'Import from CSV',
  'Account & format',
  'Column mapping',
  'Resolve categories',
  'Preview & confirm',
];

class ImportWizardScreen extends ConsumerWidget {
  const ImportWizardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(importWizardControllerProvider);
    final controller = ref.read(importWizardControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: Text(_titles[state.step])),
      body: switch (state.step) {
        0 => const StepPickFile(),
        1 => const StepAccountAndStrategy(),
        2 => const StepColumnMapping(),
        3 => const StepCategoryResolution(),
        _ => const StepPreviewConfirm(),
      },
      bottomNavigationBar: state.step == 4
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    if (state.step > 0)
                      TextButton(
                        onPressed: () => controller.goToStep(state.step - 1),
                        child: const Text('Back'),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed:
                          _canAdvance(state) ? () => controller.goToStep(state.step + 1) : null,
                      child: const Text('Next'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  bool _canAdvance(ImportWizardState state) {
    switch (state.step) {
      case 0:
        return state.hasFile;
      case 1:
        final selection = state.accountSelection;
        if (selection == null) return false;
        return selection.isCreateNew
            ? (selection.newAccountName?.trim().isNotEmpty ?? false)
            : selection.accountId != null;
      case 2:
        return state.isMappingComplete;
      case 3:
        return state.isCategoryResolutionComplete;
      default:
        return true;
    }
  }
}
