import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/auth_controller.dart';
import '../../core/sync/sync_providers.dart';

/// Web-only login flow: connect-to-server then email/password, both backed
/// by the same [AuthController] the mobile app uses (core/sync/) — there's
/// nothing web-specific about authentication itself, so this screen is new
/// UI over entirely reused business logic. See
/// features/settings/presentation/backend_connection_screen.dart for the
/// mobile equivalent (its forms are private to that file, hence the
/// duplication here rather than a shared widget).
class LoginScreen extends ConsumerWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(authControllerProvider);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: switch (controller.phase) {
            ConnectionPhase.checking =>
              const Center(child: CircularProgressIndicator()),
            ConnectionPhase.disconnected => const _ConnectServerForm(),
            ConnectionPhase.connectedLoggedOut =>
              _LoginForm(serverUrl: controller.serverUrl!),
            // ViewerRouter (web_app.dart) redirects away from /login once
            // loggedIn — this case is only ever visible for a single frame.
            ConnectionPhase.loggedIn => const Center(child: CircularProgressIndicator()),
          },
        ),
      ),
    );
  }
}

class _ConnectServerForm extends ConsumerStatefulWidget {
  const _ConnectServerForm();

  @override
  ConsumerState<_ConnectServerForm> createState() => _ConnectServerFormState();
}

class _ConnectServerFormState extends ConsumerState<_ConnectServerForm> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  String? _error;
  bool _connecting = false;

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _connecting = true;
      _error = null;
    });
    final error =
        await ref.read(authControllerProvider).connectToServer(_urlController.text);
    if (!mounted) return;
    setState(() {
      _connecting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_wallet_outlined,
                size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('Money Manager', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              'Enter the address of your self-hosted Money Manager backend.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'https://api.money.example.com',
              ),
              validator: (v) {
                final uri = Uri.tryParse(v ?? '');
                if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
                  return 'Enter a full URL, including https://';
                }
                return null;
              },
              onFieldSubmitted: (_) => _submit(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _connecting ? null : _submit,
                child: _connecting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Connect'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginForm extends ConsumerStatefulWidget {
  const _LoginForm({required this.serverUrl});
  final String serverUrl;

  @override
  ConsumerState<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _deviceNameController = TextEditingController(text: 'Web browser');
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final error = await ref.read(authControllerProvider).login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          deviceName: _deviceNameController.text.trim(),
        );
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.login, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              widget.serverUrl,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _deviceNameController,
              decoration: const InputDecoration(labelText: 'This browser\'s name'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Log in'),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => ref.read(authControllerProvider).disconnectServer(),
              child: const Text('Use a different server'),
            ),
          ],
        ),
      ),
    );
  }
}
