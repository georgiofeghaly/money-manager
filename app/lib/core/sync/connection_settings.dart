import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Persists the backend connection: server URL + this device's identity +
/// the current login session. All in secure storage (not just the tokens)
/// since the server URL itself reveals where your private server lives.
class ConnectionSettings {
  ConnectionSettings() : _storage = const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _serverUrlKey = 'server_url';
  static const _deviceIdKey = 'device_id';
  static const _deviceNameKey = 'device_name';
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userEmailKey = 'user_email';

  Future<String?> readServerUrl() => _storage.read(key: _serverUrlKey);

  Future<void> writeServerUrl(String url) =>
      _storage.write(key: _serverUrlKey, value: url);

  Future<String?> readDeviceId() => _storage.read(key: _deviceIdKey);

  /// Generated once per install and reused for every login — the server
  /// tracks devices by this id (see backend `devices` table).
  Future<String> ensureDeviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null) return existing;
    final generated = _uuid.v4();
    await _storage.write(key: _deviceIdKey, value: generated);
    return generated;
  }

  Future<String?> readDeviceName() => _storage.read(key: _deviceNameKey);

  Future<void> writeDeviceName(String name) =>
      _storage.write(key: _deviceNameKey, value: name);

  Future<String?> readAccessToken() => _storage.read(key: _accessTokenKey);

  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<String?> readUserEmail() => _storage.read(key: _userEmailKey);

  Future<void> writeSession({
    required String accessToken,
    required String refreshToken,
    required String email,
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
    await _storage.write(key: _userEmailKey, value: email);
  }

  /// Logs out but keeps the server URL and device id, so logging back in
  /// doesn't need the URL re-entered.
  Future<void> clearSession() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _userEmailKey);
  }

  /// Forgets the server entirely (used when switching to a different backend).
  Future<void> clearAll() async {
    await clearSession();
    await _storage.delete(key: _serverUrlKey);
  }
}
