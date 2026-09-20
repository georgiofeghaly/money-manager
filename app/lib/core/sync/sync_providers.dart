import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/database_provider.dart';
import 'api_client.dart';
import 'auth_controller.dart';
import 'connection_settings.dart';
import 'sync_controller.dart';
import 'sync_engine.dart';
import 'sync_triggers.dart';

final connectionSettingsProvider =
    Provider<ConnectionSettings>((ref) => ConnectionSettings());

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref.watch(connectionSettingsProvider));
});

final authControllerProvider = ChangeNotifierProvider<AuthController>((ref) {
  return AuthController(
    ref.watch(connectionSettingsProvider),
    ref.watch(apiClientProvider),
  );
});

final syncEngineProvider = Provider<SyncEngine>((ref) {
  return SyncEngine(
    ref.watch(databaseProvider),
    ref.watch(apiClientProvider),
    ref.watch(connectionSettingsProvider),
  );
});

final syncControllerProvider = ChangeNotifierProvider<SyncController>((ref) {
  return SyncController(
    ref.watch(syncEngineProvider),
    ref.watch(connectionSettingsProvider),
  );
});

/// Starts the connectivity-regained listener once, alongside the app —
/// read (not watched) from a root widget so it lives for the app's
/// lifetime. Resume-triggered sync is wired separately into LockGate.
final connectivitySyncTriggerProvider = Provider<ConnectivitySyncTrigger>((ref) {
  final trigger = ConnectivitySyncTrigger(ref.read(syncControllerProvider));
  trigger.start();
  ref.onDispose(trigger.dispose);
  return trigger;
});
