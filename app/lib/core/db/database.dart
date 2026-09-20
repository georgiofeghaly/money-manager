import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../theme/category_style.dart';
import 'connection/unsupported.dart'
    if (dart.library.io) 'connection/native.dart' as db_connection;

part 'database.g.dart';

const _uuid = Uuid();

/// Placeholder user id used until Phase 2 wires up real backend accounts.
/// Kept as a real column (not hardcoded in queries) so turning on multi-user
/// sync later doesn't require a schema migration.
const localUserId = 'local';

class Accounts extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().withDefault(const Constant(localUserId))();
  TextColumn get name => text()();
  // 'card' | 'cash' | 'savings' | 'custom'
  TextColumn get type => text()();
  RealColumn get startingBalance => real().withDefault(const Constant(0))();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get originDeviceId => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();

  @override
  Set<Column> get primaryKey => {id};
}

class Categories extends Table {
  TextColumn get id => text()();
  // Always null locally — the server assigns the real owner on push
  // regardless of what's sent, so there's nothing to set here client-side.
  TextColumn get userId => text().nullable()();
  // 'income' | 'expense'
  TextColumn get kind => text()();
  TextColumn get name => text()();
  // key into kCategoryIcons (core/theme/category_style.dart), not a raw codepoint
  TextColumn get icon => text().nullable()();
  // ARGB int; null falls back to a deterministic color derived from id
  IntColumn get color => integer().nullable()();
  BoolColumn get isSeed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get originDeviceId => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();

  @override
  Set<Column> get primaryKey => {id};
}

class Transactions extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().withDefault(const Constant(localUserId))();
  // 'income' | 'expense' | 'transfer'
  TextColumn get type => text()();
  RealColumn get amount => real()();
  DateTimeColumn get occurredAt => dateTime()();
  TextColumn get accountId =>
      text().references(Accounts, #id)();
  TextColumn get transferToAccountId =>
      text().nullable().references(Accounts, #id)();
  TextColumn get categoryId =>
      text().nullable().references(Categories, #id)();
  TextColumn get note => text().nullable()();
  // set on rows created by the CSV import wizard, null otherwise; lets a
  // bad import be bulk-reverted by soft-deleting everything with the tag
  TextColumn get importBatchId => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get originDeviceId => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();

  @override
  Set<Column> get primaryKey => {id};
}

class Budgets extends Table {
  TextColumn get id => text()();
  TextColumn get userId => text().withDefault(const Constant(localUserId))();
  TextColumn get categoryId =>
      text().references(Categories, #id)();
  // normalized to the first of the month
  DateTimeColumn get periodMonth => dateTime()();
  RealColumn get limitAmount => real()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get version => integer().withDefault(const Constant(1))();
  TextColumn get originDeviceId => text().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {userId, categoryId, periodMonth},
      ];
}

/// Client-only — no server counterpart. Written by the sync engine
/// (core/sync/sync_engine.dart) when a push is rejected as a conflict or a
/// pull would clobber a locally-pending row; read by
/// features/sync_conflicts/ for the resolution UI. Rows are JSON blobs
/// rather than typed columns because the four source tables have different
/// shapes and this table never needs to be queried by business field.
class SyncConflicts extends Table {
  TextColumn get id => text()();
  // One of the SYNC_TABLE_ORDER names ('accounts'|'categories'|'transactions'|'budgets').
  // Named syncTableName, not tableName — that name collides with Drift's
  // own Table.tableName getter.
  TextColumn get syncTableName => text()();
  TextColumn get rowId => text()();
  TextColumn get localRowJson => text()();
  TextColumn get serverRowJson => text()();
  DateTimeColumn get detectedAt => dateTime()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(
  tables: [Accounts, Categories, Transactions, Budgets, SyncConflicts],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? db_connection.openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) async {
          await m.createAll();
          await _seedCategories(this);
        },
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(categories, categories.color);
            await _backfillCategoryColors(this);
          }
          if (from < 3) {
            await m.addColumn(transactions, transactions.importBatchId);
          }
          if (from < 4) {
            await m.createTable(syncConflicts);
          }
        },
      );
}

/// name -> icon key (core/theme/category_style.dart); unmatched names fall
/// back to the 'other' icon.
const Map<String, String> _seedIconKeys = {
  'Car': 'car',
  'Groceries': 'groceries',
  'Bills & Utilities': 'bills',
  'Gift': 'gift',
  'Tools': 'tools',
  'Health': 'health',
  'Entertainment': 'entertainment',
  'Shopping': 'shopping',
  'Dining': 'dining',
  'Salary': 'salary',
  'Bonus': 'bonus',
  'Freelance': 'freelance',
};

Future<void> _seedCategories(AppDatabase db) async {
  final now = DateTime.now();

  const expenseCategories = [
    'Car',
    'Groceries',
    'Bills & Utilities',
    'Gift',
    'Tools',
    'Health',
    'Entertainment',
    'Shopping',
    'Dining',
    'Other',
  ];
  const incomeCategories = ['Salary', 'Bonus', 'Gift', 'Freelance', 'Other'];

  CategoriesCompanion buildRow(String name, String kind) {
    final id = _uuid.v4();
    return CategoriesCompanion.insert(
      id: id,
      kind: kind,
      name: name,
      icon: Value(_seedIconKeys[name] ?? 'other'),
      color: Value(defaultColorForId(id).toARGB32()),
      isSeed: const Value(true),
      updatedAt: now,
      syncStatus: const Value('pending'),
    );
  }

  await db.batch((batch) {
    batch.insertAll(db.categories, [
      for (final name in expenseCategories) buildRow(name, 'expense'),
      for (final name in incomeCategories) buildRow(name, 'income'),
    ]);
  });
}

Future<void> _backfillCategoryColors(AppDatabase db) async {
  final rows = await db.select(db.categories).get();
  await db.batch((batch) {
    for (final row in rows) {
      batch.update(
        db.categories,
        CategoriesCompanion(color: Value(defaultColorForId(row.id).toARGB32())),
        where: (c) => c.id.equals(row.id),
      );
    }
  });
}
