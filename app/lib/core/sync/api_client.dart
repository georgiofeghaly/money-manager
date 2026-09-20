import 'package:dio/dio.dart';

import 'connection_settings.dart';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class LoginResult {
  const LoginResult({
    required this.accessToken,
    required this.refreshToken,
    required this.userId,
  });

  final String accessToken;
  final String refreshToken;
  final String userId;
}

/// Thin wrapper around Dio: attaches the stored server URL + access token to
/// every request, and transparently refreshes+retries once on a 401 before
/// giving up. Every method throws [ApiException] with a message suitable to
/// show directly in the UI.
class ApiClient {
  ApiClient(this._settings) {
    _dio = Dio();
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final baseUrl = await _settings.readServerUrl();
          if (baseUrl != null) options.baseUrl = baseUrl;
          final token = await _settings.readAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final isAuthEndpoint = error.requestOptions.path.startsWith('/auth/');
          if (error.response?.statusCode == 401 && !isAuthEndpoint) {
            final refreshed = await _tryRefresh();
            if (refreshed) {
              try {
                final retried = await _dio.fetch(error.requestOptions);
                return handler.resolve(retried);
              } on DioException catch (retryError) {
                return handler.next(retryError);
              }
            }
          }
          handler.next(error);
        },
      ),
    );
  }

  late final Dio _dio;
  final ConnectionSettings _settings;

  Future<bool> _tryRefresh() async {
    final deviceId = await _settings.readDeviceId();
    final refreshToken = await _settings.readRefreshToken();
    final email = await _settings.readUserEmail();
    if (deviceId == null || refreshToken == null || email == null) return false;

    try {
      final response = await _dio.post(
        '/auth/refresh',
        data: {'deviceId': deviceId, 'refreshToken': refreshToken},
      );
      await _settings.writeSession(
        accessToken: response.data['accessToken'] as String,
        refreshToken: response.data['refreshToken'] as String,
        email: email,
      );
      return true;
    } on DioException {
      return false;
    }
  }

  Future<bool> testConnection(String url) async {
    try {
      final response = await _dio.get('$url/health');
      return response.statusCode == 200 && response.data['status'] == 'ok';
    } on DioException {
      return false;
    }
  }

  Future<LoginResult> login({
    required String email,
    required String password,
    required String deviceName,
  }) async {
    final deviceId = await _settings.ensureDeviceId();
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {
          'email': email,
          'password': password,
          'deviceId': deviceId,
          'deviceName': deviceName,
        },
      );
      return LoginResult(
        accessToken: response.data['accessToken'] as String,
        refreshToken: response.data['refreshToken'] as String,
        userId: response.data['userId'] as String,
      );
    } on DioException catch (e) {
      throw ApiException(_messageFor(e, fallback: 'Login failed'));
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.patch(
        '/auth/password',
        data: {'currentPassword': currentPassword, 'newPassword': newPassword},
      );
    } on DioException catch (e) {
      throw ApiException(_messageFor(e, fallback: 'Could not change password'));
    }
  }

  /// Raw push/pull calls — the row<->JSON shape (per-table field mapping)
  /// lives in core/sync/sync_engine.dart, this stays a thin Dio wrapper like
  /// every other method here.
  Future<Map<String, dynamic>> pushSync({
    required String deviceId,
    required Map<String, List<Map<String, dynamic>>> tables,
  }) async {
    try {
      final response = await _dio.post(
        '/sync/push',
        data: {'deviceId': deviceId, 'tables': tables},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException(_messageFor(e, fallback: 'Sync push failed'));
    }
  }

  Future<Map<String, dynamic>> pullSync({String? since, String? cursorId}) async {
    try {
      final response = await _dio.get(
        '/sync/pull',
        queryParameters: {
          if (since != null) 'since': since,
          if (cursorId != null && cursorId.isNotEmpty) 'cursorId': cursorId,
        },
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException(_messageFor(e, fallback: 'Sync pull failed'));
    }
  }

  /// The caller's own devices, for labeling sync conflicts with a device
  /// name instead of a raw UUID (see features/sync_conflicts/).
  Future<List<Map<String, dynamic>>> fetchDevices() async {
    try {
      final response = await _dio.get('/devices');
      return (response.data as List).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw ApiException(_messageFor(e, fallback: 'Could not load devices'));
    }
  }

  /// `{userId, email, displayName, isAdmin}` — used both to greet the user
  /// and, on web, to gate the /admin route (see web/admin/).
  Future<Map<String, dynamic>> fetchMe() async {
    try {
      final response = await _dio.get('/auth/me');
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException(_messageFor(e, fallback: 'Could not load account info'));
    }
  }

  /// Metadata only (sign-in/sync status) — the backend's /admin routes never
  /// return financial fields, so there's nothing sensitive for this client
  /// to accidentally render.
  Future<List<Map<String, dynamic>>> fetchAdminUsers() async {
    try {
      final response = await _dio.get('/admin/users');
      return (response.data as List).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw ApiException(_messageFor(e, fallback: 'Could not load users'));
    }
  }

  Future<List<Map<String, dynamic>>> fetchAdminUserDevices(String userId) async {
    try {
      final response = await _dio.get('/admin/users/$userId/devices');
      return (response.data as List).cast<Map<String, dynamic>>();
    } on DioException catch (e) {
      throw ApiException(_messageFor(e, fallback: 'Could not load devices'));
    }
  }

  /// Returns `{id, email, displayName, generatedPassword}` — the password is
  /// shown exactly once by the caller, matching create-user.ts's CLI
  /// convention; nothing re-fetches or re-displays it after this call.
  Future<Map<String, dynamic>> createAdminUser({
    required String email,
    required String displayName,
    bool isAdmin = false,
  }) async {
    try {
      final response = await _dio.post(
        '/admin/users',
        data: {'email': email, 'displayName': displayName, 'isAdmin': isAdmin},
      );
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      throw ApiException(_messageFor(e, fallback: 'Could not create user'));
    }
  }

  String _messageFor(DioException e, {required String fallback}) {
    final data = e.response?.data;
    if (data is Map && data['error'] is String) return data['error'] as String;
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout) {
      return 'Couldn\'t reach the server';
    }
    return fallback;
  }
}
