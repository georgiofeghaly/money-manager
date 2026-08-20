import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:money_manager/core/db/database.dart';
import 'package:money_manager/core/db/database_provider.dart';
import 'package:money_manager/core/sync/api_client.dart';
import 'package:money_manager/core/sync/auth_controller.dart';
import 'package:money_manager/core/sync/connection_settings.dart';
import 'package:money_manager/core/sync/sync_providers.dart';
import 'package:money_manager/features/lock/application/lock_controller.dart';
import 'package:money_manager/features/lock/application/lock_providers.dart';
import 'package:money_manager/features/lock/data/biometric_auth.dart';
import 'package:money_manager/features/lock/data/pin_storage.dart';
import 'package:money_manager/main.dart';

void main() {
  testWidgets('App shell shows Calendar and Accounts tabs', (
    WidgetTester tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(AppDatabase(NativeDatabase.memory())),
        lockControllerProvider.overrideWith(
          (ref) => LockController.debugUnlocked(PinStorage(), BiometricAuth()),
        ),
        authControllerProvider.overrideWith(
          (ref) => AuthController.debugDisconnected(
            ConnectionSettings(),
            ApiClient(ConnectionSettings()),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MoneyManagerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Calendar'), findsWidgets);
    expect(find.text('Accounts'), findsWidgets);
    expect(find.byIcon(Icons.add), findsOneWidget);

    // Dispose the container and flush drift's stream-cleanup timer ourselves,
    // so the framework's post-test "no pending timers" check doesn't trip on
    // the Timer(Duration.zero) drift schedules when cancelling a query stream.
    container.dispose();
    await tester.pump(Duration.zero);
  });
}
