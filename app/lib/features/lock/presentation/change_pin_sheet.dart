import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/lock_providers.dart';

class ChangePinSheet extends ConsumerStatefulWidget {
  const ChangePinSheet({super.key});

  @override
  ConsumerState<ChangePinSheet> createState() => _ChangePinSheetState();
}

class _ChangePinSheetState extends ConsumerState<ChangePinSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_newController.text != _confirmController.text) {
      setState(() => _error = 'New PINs don\'t match');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    final ok = await ref.read(lockControllerProvider).changePin(
          currentPin: _currentController.text,
          newPin: _newController.text,
        );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (!ok) {
      setState(() => _error = 'Current PIN is incorrect');
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN changed')),
    );
  }

  String? _validatePin(String? v) {
    if (v == null || v.length != 6 || int.tryParse(v) == null) {
      return 'Enter a 6-digit PIN';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Change PIN', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _currentController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              decoration:
                  const InputDecoration(labelText: 'Current PIN', counterText: ''),
              validator: _validatePin,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              decoration: const InputDecoration(labelText: 'New PIN', counterText: ''),
              validator: _validatePin,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmController,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              decoration:
                  const InputDecoration(labelText: 'Confirm new PIN', counterText: ''),
              validator: _validatePin,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Change PIN'),
            ),
          ],
        ),
      ),
    );
  }
}
