import 'dart:async';

import 'package:flutter/foundation.dart';

import 'connection_settings.dart';
import 'sync_engine.dart';
import 'sync_models.dart';

/// Same shape as AuthController/LockController: a ChangeNotifier holding
/// in-memory UI state, backed by the actual work in [SyncEngine]. Only
/// meaningful once the user is logged in — callers should check
/// AuthController.phase before invoking these.
class SyncController extends ChangeNotifier {
  SyncController(this._engine, this._settings) {
    unawaited(_init());
  }

  /// Skips reading `flutter_secure_storage` entirely — for widget tests,
  /// same reasoning as AuthController.debugDisconnected.
  @visibleForTesting
  SyncController.debugIdle(this._engine, this._settings);

  final SyncEngine _engine;
  final ConnectionSettings _settings;

  SyncProgress progress = const SyncProgress();
  bool _syncing = false;

  /// Restores the last-known sync state on app start, so the Settings row
  /// shows "Synced 3h ago" immediately rather than resetting to blank until
  /// the next sync pass runs.
  Future<void> _init() async {
    final lastSyncedAt = await _settings.readLastSyncedAt();
    final lastStatus = await _settings.readLastSyncStatus();
    progress = SyncProgress(
      phase: lastStatus == 'error' ? SyncPhase.error : SyncPhase.idle,
      lastSyncedAt: lastSyncedAt,
    );
    notifyListeners();
  }

  Future<void> syncNow() async {
    // Coalesce concurrent triggers (resume + connectivity + manual tap
    // landing at once) into a single in-flight pass rather than racing two
    // pushes against the same outbox.
    if (_syncing) return;
    _syncing = true;
    try {
      await _engine.runSync(
        onProgress: (p) {
          progress = p;
          notifyListeners();
        },
      );
    } on Object {
      // SyncEngine already recorded the error into `progress` via
      // onProgress before rethrowing — nothing further to surface here.
      // Swallowed so a failed background sync (e.g. resume-triggered)
      // doesn't crash the app; the Settings row reflects the error state.
    } finally {
      _syncing = false;
    }
  }

  Future<void> syncOnResume() => syncNow();

  Future<void> syncOnConnectivityRegained() => syncNow();
}
