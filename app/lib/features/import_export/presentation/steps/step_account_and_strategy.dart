import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../accounts/application/account_providers.dart';
import '../../application/import_wizard_controller.dart';
import '../../data/import_parser.dart';

const _createNewSentinel = '__create_new__';

class StepAccountAndStrategy extends ConsumerStatefulWidget {
  const StepAccountAndStrategy({super.key});

  @override
  ConsumerState<StepAccountAndStrategy> createState() => _StepAccountAndStrategyState();
}

class _StepAccountAndStrategyState extends ConsumerState<StepAccountAndStrategy> {
  late final TextEditingController _newAccountNameController = TextEditingController(
    text: ref.read(importWizardControllerProvider).accountSelection?.newAccountName ?? '',
  );

  @override
  void dispose() {
    _newAccountNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(importWizardControllerProvider);
    final controller = ref.read(importWizardControllerProvider.notifier);
    final accountsAsync = ref.watch(accountsForLookupProvider);

    final isCreatingNew = state.accountSelection?.isCreateNew ?? false;
    final selectedValue = isCreatingNew ? _createNewSentinel : state.accountSelection?.accountId;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Which account are these transactions for?',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          accountsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (err, st) => Text('Error: $err'),
            data: (accounts) => DropdownButtonFormField<String>(
              initialValue: selectedValue,
              decoration: const InputDecoration(labelText: 'Account'),
              items: [
                for (final a in accounts) DropdownMenuItem(value: a.id, child: Text(a.name)),
                const DropdownMenuItem(
                  value: _createNewSentinel,
                  child: Text('+ Create new account'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                if (value == _createNewSentinel) {
                  controller.setAccountSelection(
                    AccountSelection.createNew(_newAccountNameController.text),
                  );
                } else {
                  controller.setAccountSelection(AccountSelection.existing(value));
                }
              },
            ),
          ),
          if (isCreatingNew) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _newAccountNameController,
              decoration: const InputDecoration(labelText: 'New account name'),
              onChanged: (name) =>
                  controller.setAccountSelection(AccountSelection.createNew(name)),
            ),
          ],
          const SizedBox(height: 24),
          Text('How does the file encode income vs. expense?',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          SegmentedButton<AmountStrategy>(
            segments: const [
              ButtonSegment(
                value: AmountStrategy.signedAmount,
                label: Text('Signed amount'),
              ),
              ButtonSegment(
                value: AmountStrategy.debitCredit,
                label: Text('Debit & Credit'),
              ),
              ButtonSegment(
                value: AmountStrategy.amountPlusType,
                label: Text('Amount + Type'),
              ),
            ],
            selected: {state.amountStrategy},
            onSelectionChanged: (selection) => controller.setAmountStrategy(selection.first),
          ),
          const SizedBox(height: 8),
          Text(
            _strategyHelp(state.amountStrategy),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  String _strategyHelp(AmountStrategy strategy) => switch (strategy) {
        AmountStrategy.signedAmount =>
          'One Amount column; negative values are expenses, positive are income.',
        AmountStrategy.debitCredit => 'Separate Debit and Credit columns.',
        AmountStrategy.amountPlusType =>
          'An Amount column (always positive) plus a Type column (e.g. Debit/Credit).',
      };
}
