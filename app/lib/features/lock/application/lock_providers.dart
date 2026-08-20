import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/biometric_auth.dart';
import '../data/pin_storage.dart';
import 'lock_controller.dart';

final pinStorageProvider = Provider<PinStorage>((ref) => PinStorage());

final biometricAuthProvider = Provider<BiometricAuth>((ref) => BiometricAuth());

final lockControllerProvider = ChangeNotifierProvider<LockController>((ref) {
  return LockController(
    ref.watch(pinStorageProvider),
    ref.watch(biometricAuthProvider),
  );
});
