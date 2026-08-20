import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/database.dart';

const _uuid = Uuid();

class CategoryRepository {
  CategoryRepository(this._db);

  final AppDatabase _db;

  Stream<List<Category>> watchCategories({String? kind}) {
    final query = _db.select(_db.categories)
      ..where((c) => c.deletedAt.isNull())
      ..orderBy([(c) => OrderingTerm.asc(c.name)]);
    if (kind != null) {
      query.where((c) => c.kind.equals(kind));
    }
    return query.watch();
  }

  /// Includes soft-deleted categories, so a transaction form editing an old
  /// entry can still resolve/display a category that's since been deleted.
  Stream<List<Category>> watchCategoriesForLookup(String kind) {
    return (_db.select(_db.categories)
          ..where((c) => c.kind.equals(kind))
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .watch();
  }

  /// All categories, any kind, including soft-deleted — for resolving a
  /// transaction's category name/icon/color for display purposes only.
  Stream<List<Category>> watchAllCategoriesForLookup() {
    return _db.select(_db.categories).watch();
  }

  Future<void> createCategory({
    required String name,
    required String kind,
    required String iconKey,
    required Color color,
  }) {
    final id = _uuid.v4();
    return _db.into(_db.categories).insert(
          CategoriesCompanion.insert(
            id: id,
            kind: kind,
            name: name,
            icon: Value(iconKey),
            color: Value(color.toARGB32()),
            updatedAt: DateTime.now(),
          ),
        );
  }

  Future<void> updateCategory({
    required String id,
    required String name,
    required String iconKey,
    required Color color,
  }) {
    return (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(
        name: Value(name),
        icon: Value(iconKey),
        color: Value(color.toARGB32()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Soft-delete: existing transactions referencing this category keep
  /// resolving its name/icon, it just disappears from create/edit pickers.
  Future<void> deleteCategory(String id) {
    return (_db.update(_db.categories)..where((c) => c.id.equals(id))).write(
      CategoriesCompanion(deletedAt: Value(DateTime.now())),
    );
  }
}
