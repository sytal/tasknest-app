import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tasknest_app/main.dart' as app;

/// Requires the API running at http://127.0.0.1:8012 with seeded data
/// (`php artisan migrate:fresh --seed`). Run with:
///   flutter test integration_test -d chrome   (needs chromedriver)
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> login(WidgetTester t, String email) async {
    await t.enterText(find.byType(TextFormField).at(0), email);
    await t.enterText(find.byType(TextFormField).at(1), 'password');
    await t.tap(find.text('Log In'));
    await t.pumpAndSettle(const Duration(seconds: 3));
  }

  setUp(() async => SharedPreferences.setMockInitialValues({}));

  for (final entry in {
    'director@tasknest.test': true,
    'ceo@tasknest.test': true,
    'alice@tasknest.test': false,
  }.entries) {
    testWidgets('login as ${entry.key}, see dashboard, FAB only for management', (t) async {
      app.main();
      await t.pumpAndSettle();
      await login(t, entry.key);
      expect(find.text('Dashboard'), findsWidgets);
      expect(find.byTooltip('New project'), entry.value ? findsOneWidget : findsNothing);
    });
  }

  testWidgets('session survives restart and logout returns to login', (t) async {
    app.main();
    await t.pumpAndSettle();
    await login(t, 'alice@tasknest.test');
    app.main();
    await t.pumpAndSettle(const Duration(seconds: 3));
    expect(find.text('Dashboard'), findsWidgets);
    await t.tap(find.text('Profile').last);
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('Log Out'), 200);
    await t.tap(find.text('Log Out'));
    await t.pumpAndSettle();
    expect(find.text('Log In'), findsOneWidget);
  });
}
