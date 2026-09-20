import '../../core/db/database.dart';
import '../../features/categories/data/category_repository.dart';
import 'watch_derived.dart';
import 'web_data_store.dart';

class ApiCategoryRepository implements CategoryReader {
  ApiCategoryRepository(this._store);

  final WebDataStore _store;

  @override
  Stream<List<Category>> watchCategories({String? kind}) => watchDerived(_store, () {
        var rows = _store.categories.where((c) => c.deletedAt == null);
        if (kind != null) rows = rows.where((c) => c.kind == kind);
        return rows.toList()..sort((a, b) => a.name.compareTo(b.name));
      });

  @override
  Stream<List<Category>> watchCategoriesForLookup(String kind) => watchDerived(_store, () {
        final rows = _store.categories.where((c) => c.kind == kind).toList()
          ..sort((a, b) => a.name.compareTo(b.name));
        return rows;
      });

  @override
  Stream<List<Category>> watchAllCategoriesForLookup() =>
      watchDerived(_store, () => _store.categories);
}
