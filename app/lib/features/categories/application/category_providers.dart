import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/database.dart';
import '../../../core/db/database_provider.dart';
import '../../../web/data/api_category_repository.dart';
import '../../../web/data/web_data_providers.dart';
import '../data/category_repository.dart';

final categoryRepositoryProvider = Provider<CategoryReader>((ref) {
  if (kIsWeb) return ApiCategoryRepository(ref.watch(webDataStoreProvider));
  return DriftCategoryRepository(ref.watch(databaseProvider));
});

final categoryWriterProvider = Provider<CategoryWriter>((ref) {
  final reader = ref.watch(categoryRepositoryProvider);
  if (reader is CategoryWriter) return reader as CategoryWriter;
  throw UnsupportedError('Category writes are not available on this platform.');
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
