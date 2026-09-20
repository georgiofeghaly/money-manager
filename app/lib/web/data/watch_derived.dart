import 'web_data_store.dart';

/// Mimics Drift's `.watch()` contract (emit the current value immediately,
/// then again on every change) over [WebDataStore], which has no live query
/// engine of its own — just a full reload on [WebDataStore.refresh].
Stream<T> watchDerived<T>(WebDataStore store, T Function() compute) async* {
  yield compute();
  yield* store.changes.map((_) => compute());
}
