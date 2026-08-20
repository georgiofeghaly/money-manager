import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/auth_controller.dart';
import '../../../core/sync/sync_providers.dart';
import '../../../core/widgets/confirm_dialog.dart';
import 'change_password_sheet.dart';

class BackendConnectionScreen extends ConsumerWidget {
  const BackendConnectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Backend & Sync')),
      body: switch (controller.phase) {
        ConnectionPhase.checking =>
          const Center(child: CircularProgressIndicator()),
        ConnectionPhase.disconnected => const _ConnectServerForm(),
        ConnectionPhase.connectedLoggedOut => _LoginForm(serverUrl: controller.serverUrl!),
        ConnectionPhase.loggedIn => _ConnectedPanel(controller: controller),
      },
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.dns_outlined, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text('Connect to your server', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Enter the address of your self-hosted Money Manager backend — '
              'your own domain, or a local address if you\'re on the home '
              'network or VPN.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Server URL',
                hintText: 'https://money.example.com',
              ),
              validator: (v) {
                final uri = Uri.tryParse(v ?? '');
                if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
                  return 'Enter a full URL, including https://';
                }
                return null;
              },
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
  final _deviceNameController = TextEditingController(text: 'My phone');
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
          mainAxisAlignment: MainAxisAlignment.center,
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
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _deviceNameController,
              decoration: const InputDecoration(labelText: 'This device\'s name'),
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

class _ConnectedPanel extends ConsumerWidget {
  const _ConnectedPanel({required this.controller});
  final AuthController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      children: [
        ListTile(
          leading: const Icon(Icons.dns_outlined),
          title: Text(controller.serverUrl ?? ''),
          subtitle: const Text('Server'),
        ),
        ListTile(
          leading: const Icon(Icons.person_outline),
          title: Text(controller.userEmail ?? ''),
          subtitle: const Text('Signed in as'),
        ),
        const Divider(),
        ListTile(
          leading: const Icon(Icons.password_outlined),
          title: const Text('Change password'),
          subtitle: const Text('Signs other devices out'),
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => const ChangePasswordSheet(),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Log out'),
          onTap: () => ref.read(authControllerProvider).logout(),
        ),
        ListTile(
          leading: Icon(Icons.link_off, color: Theme.of(context).colorScheme.error),
          title: Text(
            'Forget this server',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          onTap: () async {
            final confirmed = await confirmDialog(
              context,
              title: 'Forget this server?',
              message: 'You\'ll need to re-enter the server address and log in again.',
              confirmLabel: 'Forget',
            );
            if (confirmed) {
              await ref.read(authControllerProvider).disconnectServer();
            }
          },
        ),
      ],
    );
  }
}
