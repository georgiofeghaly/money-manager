import 'package:drift/drift.dart';

QueryExecutor openConnection() {
  throw UnsupportedError(
    'The local Drift database is not available on this platform. '
    'Web builds are read-only and talk to the API directly.',
  );
}
