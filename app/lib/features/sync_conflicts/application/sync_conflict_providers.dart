import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/sync/sync_providers.dart';
import '../data/sync_conflict_repository.dart';

final syncConflictRepositoryProvider = Provider<SyncConflictRepository>((ref) {
  return SyncConflictRepository(ref.watch(databaseProvider));
});

final openSyncConflictsProvider = StreamProvider<List<SyncConflict>>((ref) {
  return ref.watch(syncConflictRepositoryProvider).watchOpenConflicts();
});

/// This device's own devices list, for labeling a conflict "edited on
/// Tablet" instead of a raw device UUID. Best-effort: if the request fails
/// (e.g. temporarily offline while resolving a conflict from an earlier
/// sync), the diff screen falls back to a shortened id.
final devicesForLookupProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(apiClientProvider).fetchDevices();
});
