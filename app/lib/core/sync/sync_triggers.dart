import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:workmanager/workmanager.dart';

import '../db/database.dart';
import 'api_client.dart';
import 'connection_settings.dart';
import 'sync_controller.dart';
import 'sync_engine.dart';

const _periodicSyncTaskName = 'money_manager_periodic_sync';

/// Runs in a separate headless isolate — no Riverpod `ref`, no widget tree,
/// so it builds its own database/API client rather than reading providers.
/// `vm:entry-point` keeps the tree-shaker from stripping it, since nothing
/// in the main isolate calls it directly.
@pragma('vm:entry-point')
void syncCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final settings = ConnectionSettings();
    final hasSession = await settings.readAccessToken() != null;
    if (!hasSession) return true;

    final db = AppDatabase();
    try {
      final engine = SyncEngine(db, ApiClient(settings), settings);
      await engine.runSync();
    } catch (_) {
      // Best-effort: a failed background pass just leaves lastSyncStatus as
      // 'error' for the next foreground sync (manual/resume/connectivity)
      // to retry and surface properly in the Settings row.
    } finally {
      await db.close();
    }
    return true;
  });
}

/// Registers the ~15-minute periodic background task. The interval is a
/// floor, not a guarantee — Android throttles/batches periodic WorkManager
/// tasks under Doze/App Standby, which this can't work around from inside
/// the app (see PRD.md's Phase 5 battery-optimization-exemption note).
Future<void> registerPeriodicSync() async {
  await Workmanager().initialize(syncCallbackDispatcher);
  await Workmanager().registerPeriodicTask(
    _periodicSyncTaskName,
    _periodicSyncTaskName,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(networkType: NetworkType.connected),
    existingWorkPolicy: ExistingWorkPolicy.keep,
  );
}

/// Foreground connectivity-regained trigger. Resume-triggered sync is
/// wired separately, directly into LockGate's existing lifecycle observer
/// (see features/lock/presentation/lock_gate.dart) rather than a second
/// WidgetsBindingObserver here.
class ConnectivitySyncTrigger {
  ConnectivitySyncTrigger(this._controller);

  final SyncController _controller;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  void start() {
    _subscription = Connectivity().onConnectivityChanged.listen((results) {
      final hasConnection = results.any((r) => r != ConnectivityResult.none);
      if (hasConnection) {
        unawaited(_controller.syncOnConnectivityRegained());
      }
    });
  }

  void dispose() {
    _subscription?.cancel();
  }
}
