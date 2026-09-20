/// The four syncable tables, in FK-safe write order — must match the
/// backend's SYNC_TABLE_ORDER (backend/src/modules/sync/tables.ts) exactly,
/// since both push-accept and pull-apply loops depend on parents (accounts,
/// categories) being written before children (transactions, budgets).
enum SyncTableName { accounts, categories, transactions, budgets }

enum SyncPhase { idle, syncing, error }

/// Snapshot of sync state, surfaced by [SyncController] to Settings and the
/// AppShell progress strip.
class SyncProgress {
  const SyncProgress({
    this.phase = SyncPhase.idle,
    this.current = 0,
    this.total = 0,
    this.lastSyncedAt,
    this.lastError,
  });

  final SyncPhase phase;
  final int current;
  final int total;
  final DateTime? lastSyncedAt;
  final String? lastError;

  SyncProgress copyWith({
    SyncPhase? phase,
    int? current,
    int? total,
    DateTime? lastSyncedAt,
    String? lastError,
    bool clearError = false,
  }) {
    return SyncProgress(
      phase: phase ?? this.phase,
      current: current ?? this.current,
      total: total ?? this.total,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}
