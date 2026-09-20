/// Bump only if this JSON *shape* changes (new/removed top-level fields) —
/// independent of [AppDatabase.schemaVersion], which tracks the SQLite
/// schema of the row payloads themselves.
const kBackupFormatVersion = 1;

/// A full snapshot of every table (including archived accounts and
/// soft-deleted rows, so a restore is byte-faithful), as raw JSON row maps
/// straight from each Drift DataClass's generated `toJson()`.
class BackupPayload {
  const BackupPayload({
    required this.formatVersion,
    required this.schemaVersion,
    required this.exportedAt,
    required this.accounts,
    required this.categories,
    required this.transactions,
    required this.budgets,
  });

  final int formatVersion;
  final int schemaVersion;
  final DateTime exportedAt;
  final List<Map<String, dynamic>> accounts;
  final List<Map<String, dynamic>> categories;
  final List<Map<String, dynamic>> transactions;
  final List<Map<String, dynamic>> budgets;

  Map<String, dynamic> toJson() => {
        'formatVersion': formatVersion,
        'schemaVersion': schemaVersion,
        'exportedAt': exportedAt.toIso8601String(),
        'accounts': accounts,
        'categories': categories,
        'transactions': transactions,
        'budgets': budgets,
      };

  factory BackupPayload.fromJson(Map<String, dynamic> json) {
    return BackupPayload(
      formatVersion: json['formatVersion'] as int,
      schemaVersion: json['schemaVersion'] as int,
      exportedAt: DateTime.parse(json['exportedAt'] as String),
      accounts: (json['accounts'] as List).cast<Map<String, dynamic>>(),
      categories: (json['categories'] as List).cast<Map<String, dynamic>>(),
      transactions: (json['transactions'] as List).cast<Map<String, dynamic>>(),
      budgets: (json['budgets'] as List).cast<Map<String, dynamic>>(),
    );
  }
}
