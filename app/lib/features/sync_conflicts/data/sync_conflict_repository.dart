import 'dart:convert';

import '../../../core/db/database.dart';
import '../../../core/sync/outbox.dart';
import '../../../core/sync/sync_models.dart';

class SyncConflictRepository {
  SyncConflictRepository(AppDatabase db) : _outbox = Outbox(db);

  final Outbox _outbox;

  Stream<List<SyncConflict>> watchOpenConflicts() => _outbox.watchOpenConflicts();

  Map<String, dynamic> localRow(SyncConflict conflict) =>
      jsonDecode(conflict.localRowJson) as Map<String, dynamic>;

  Map<String, dynamic> serverRow(SyncConflict conflict) =>
      jsonDecode(conflict.serverRowJson) as Map<String, dynamic>;

  SyncTableName tableOf(SyncConflict conflict) =>
      SyncTableName.values.byName(conflict.syncTableName);

  /// Keeps this device's own field values, but adopts the server's version
  /// number as the new baseline so the next push isn't rejected again.
  Future<void> resolveKeepMine(SyncConflict conflict) => _resolve(conflict, useLocal: true);

  /// Discards this device's edit in favor of the server's field values.
  Future<void> resolveKeepOther(SyncConflict conflict) => _resolve(conflict, useLocal: false);

  /// Same as [resolveKeepMine] — fast-forwards the version baseline and
  /// keeps local field values — but the caller (conflict_diff_screen.dart)
  /// follows this up by opening the normal edit form pre-filled with those
  /// values, so the user can adjust before the next push goes out.
  Future<void> resolveManually(SyncConflict conflict) => _resolve(conflict, useLocal: true);

  Future<void> _resolve(SyncConflict conflict, {required bool useLocal}) async {
    final table = tableOf(conflict);
    final server = serverRow(conflict);
    final chosen = useLocal ? localRow(conflict) : server;
    await _outbox.resolveConflict(
      table,
      conflict.rowId,
      chosen,
      version: server['version'] as int,
    );
    await _outbox.markConflictResolved(conflict.id);
  }
}
