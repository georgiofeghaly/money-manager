import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/database_provider.dart';
import '../data/category_repository.dart';

final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(databaseProvider));
});

/// kind = 'income' | 'expense'
final categoriesByKindProvider =
    StreamProvider.family<List<Category>, String>((ref, kind) {
  return ref.watch(categoryRepositoryProvider).watchCategories(kind: kind);
});

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchCategories();
});

final categoriesForLookupByKindProvider =
    StreamProvider.family<List<Category>, String>((ref, kind) {
  return ref.watch(categoryRepositoryProvider).watchCategoriesForLookup(kind);
});

final categoriesAllForLookupProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchAllCategoriesForLookup();
});
