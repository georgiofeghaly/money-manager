import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/sync/sync_providers.dart';

/// `{id, email, displayName, isAdmin}` for the currently logged-in user —
/// used to gate /admin (see AdminGate). autoDispose + re-fetched on every
/// AdminGate build, not cached app-wide, since isAdmin can change server-side
/// between visits.
final meProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(apiClientProvider).fetchMe();
});

final adminUsersProvider = FutureProvider.autoDispose((ref) {
  return ref.watch(apiClientProvider).fetchAdminUsers();
});

final adminUserDevicesProvider =
    FutureProvider.autoDispose.family<List<Map<String, dynamic>>, String>((ref, userId) {
  return ref.watch(apiClientProvider).fetchAdminUserDevices(userId);
});
