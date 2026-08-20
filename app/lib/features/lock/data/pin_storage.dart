import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Salted, iterated SHA-256 (not a real KDF like PBKDF2/argon2id — kept
/// dependency-free) storage for the app-lock PIN. The raw PIN itself is
/// never persisted, only this hash + its salt.
class PinStorage {
  PinStorage() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _saltKey = 'pin_salt';
  static const _hashKey = 'pin_hash';
  static const _iterations = 10000;

  Future<bool> hasPin() async {
    return (await _storage.read(key: _hashKey)) != null;
  }

  Future<void> setPin(String pin) async {
    final salt = _generateSalt();
    await _storage.write(key: _saltKey, value: base64Encode(salt));
    await _storage.write(key: _hashKey, value: _hash(pin, salt));
  }

  Future<bool> verifyPin(String pin) async {
    final saltEncoded = await _storage.read(key: _saltKey);
    final expectedHash = await _storage.read(key: _hashKey);
    if (saltEncoded == null || expectedHash == null) return false;
    return _hash(pin, base64Decode(saltEncoded)) == expectedHash;
  }

  List<int> _generateSalt() {
    final random = Random.secure();
    return List<int>.generate(16, (_) => random.nextInt(256));
  }

  String _hash(String pin, List<int> salt) {
    var digest = sha256.convert([...utf8.encode(pin), ...salt]);
    for (var i = 1; i < _iterations; i++) {
      digest = sha256.convert([...digest.bytes, ...salt]);
    }
    return digest.toString();
  }
}
