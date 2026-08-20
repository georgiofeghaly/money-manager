import 'dart:async';

import 'package:flutter/foundation.dart';

import 'api_client.dart';
import 'connection_settings.dart';

enum ConnectionPhase { checking, disconnected, connectedLoggedOut, loggedIn }

class AuthController extends ChangeNotifier {
  AuthController(this._settings, this._api) {
    unawaited(_init());
  }

  /// Skips reading `flutter_secure_storage` entirely, starting disconnected
  /// — for widget tests, where that platform channel isn't available and a
  /// real [AuthController] would hang forever in `_init()`.
  @visibleForTesting
  AuthController.debugDisconnected(this._settings, this._api) {
    phase = ConnectionPhase.disconnected;
  }

  final ConnectionSettings _settings;
  final ApiClient _api;

  ConnectionPhase phase = ConnectionPhase.checking;
  String? serverUrl;
  String? userEmail;

  Future<void> _init() async {
    serverUrl = await _settings.readServerUrl();
    userEmail = await _settings.readUserEmail();
    final hasToken = await _settings.readAccessToken() != null;

    phase = serverUrl == null
        ? ConnectionPhase.disconnected
        : (hasToken ? ConnectionPhase.loggedIn : ConnectionPhase.connectedLoggedOut);
    notifyListeners();
  }

  /// Returns null on success, or an error message to show the user.
  Future<String?> connectToServer(String url) async {
    final normalized = url.trim().replaceAll(RegExp(r'/+$'), '');
    final ok = await _api.testConnection(normalized);
    if (!ok) return 'Couldn\'t reach a Money Manager server at that address';

    await _settings.writeServerUrl(normalized);
    serverUrl = normalized;
    phase = ConnectionPhase.connectedLoggedOut;
    notifyListeners();
    return null;
  }

  Future<String?> login({
    required String email,
    required String password,
    required String deviceName,
  }) async {
    try {
      final result = await _api.login(
        email: email,
        password: password,
        deviceName: deviceName,
      );
      await _settings.writeDeviceName(deviceName);
      await _settings.writeSession(
        accessToken: result.accessToken,
        refreshToken: result.refreshToken,
        email: email,
      );
      userEmail = email;
      phase = ConnectionPhase.loggedIn;
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _api.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return null;
    } on ApiException catch (e) {
      return e.message;
    }
  }

  Future<void> logout() async {
    await _settings.clearSession();
    userEmail = null;
    phase = ConnectionPhase.connectedLoggedOut;
    notifyListeners();
  }

  /// Forgets the server entirely, for switching to a different backend.
  Future<void> disconnectServer() async {
    await _settings.clearAll();
    serverUrl = null;
    userEmail = null;
    phase = ConnectionPhase.disconnected;
    notifyListeners();
  }
}
