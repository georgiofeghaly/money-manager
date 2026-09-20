import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/database_provider.dart';
import '../../../core/sync/outbox.dart';

final _outboxProvider = Provider<Outbox>((ref) {
  return Outbox(ref.watch(databaseProvider));
});

final syncRejectionsProvider = StreamProvider<List<SyncRejection>>((ref) {
  return ref.watch(_outboxProvider).watchRejections();
});

final syncRejectionCountProvider = StreamProvider<int>((ref) {
  return ref.watch(_outboxProvider).watchRejectionCount();
});
