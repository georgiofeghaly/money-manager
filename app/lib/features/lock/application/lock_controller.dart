import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/biometric_auth.dart';
import '../data/pin_storage.dart';

enum LockPhase { checking, needsSetup, locked, unlocked }

/// How long the app can sit backgrounded before the next resume re-locks it
/// — avoids re-locking on a quick app-switcher glance.
const _reLockGracePeriod = Duration(seconds: 5);

class LockController extends ChangeNotifier {
  LockController(this._pinStorage, this._biometricAuth) {
    unawaited(_init());
  }

  /// Skips PIN/biometric setup entirely, starting already unlocked — for
  /// widget tests, where `flutter_secure_storage`'s platform channel isn't
  /// available and a real [LockController] would hang forever in `_init()`.
  @visibleForTesting
  LockController.debugUnlocked(this._pinStorage, this._biometricAuth) {
    phase = LockPhase.unlocked;
  }

  final PinStorage _pinStorage;
  final BiometricAuth _biometricAuth;

  LockPhase phase = LockPhase.checking;
  DateTime? _backgroundedAt;

  Future<void> _init() async {
    final hasPin = await _pinStorage.hasPin();
    phase = hasPin ? LockPhase.locked : LockPhase.needsSetup;
    notifyListeners();
    if (hasPin) unawaited(tryBiometric());
  }

  Future<void> completeSetup(String pin) async {
    await _pinStorage.setPin(pin);
    phase = LockPhase.unlocked;
    notifyListeners();
  }

  Future<bool> unlockWithPin(String pin) async {
    final ok = await _pinStorage.verifyPin(pin);
    if (ok) {
      phase = LockPhase.unlocked;
      notifyListeners();
    }
    return ok;
  }

  /// Returns true on success, false if [currentPin] didn't match.
  Future<bool> changePin({required String currentPin, required String newPin}) async {
    final ok = await _pinStorage.verifyPin(currentPin);
    if (!ok) return false;
    await _pinStorage.setPin(newPin);
    return true;
  }

  Future<void> tryBiometric() async {
    if (phase != LockPhase.locked) return;
    if (!await _biometricAuth.isAvailable()) return;
    final ok = await _biometricAuth.authenticate();
    if (ok) {
      phase = LockPhase.unlocked;
      notifyListeners();
    }
  }

  void onAppPaused() {
    _backgroundedAt = DateTime.now();
  }

  void onAppResumed() {
    if (phase != LockPhase.unlocked) return;
    final backgroundedAt = _backgroundedAt;
    if (backgroundedAt == null) return;
    if (DateTime.now().difference(backgroundedAt) > _reLockGracePeriod) {
      phase = LockPhase.locked;
      notifyListeners();
      unawaited(tryBiometric());
    }
  }
}
