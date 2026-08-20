import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'auth_controller.dart';
import 'connection_settings.dart';

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
