import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/sync_providers.dart';
import 'web_data_store.dart';

/// The web app's single in-memory data snapshot — see WebDataStore. Kept
/// alive for the provider container's lifetime (not autoDispose) so
/// navigating between viewer screens doesn't re-fetch.
final webDataStoreProvider = Provider<WebDataStore>((ref) {
  final store = WebDataStore(ref.watch(apiClientProvider));
  ref.onDispose(store.dispose);
  return store;
});
