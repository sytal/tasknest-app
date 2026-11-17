import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tasknest_app/main.dart' as app;

/// Runs the real app on a device/emulator against the API given by
/// `--dart-define=API_BASE_URL=...` with the demo seed data:
///   flutter test integration_test -d <device> \
///     --dart-define=API_BASE_URL=http://127.0.0.1:8014/api
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester t, [int secs = 3]) => t.pumpAndSettle(
    const Duration(milliseconds: 300),
    EnginePhase.sendSemanticsUpdate,
    Duration(seconds: secs + 20),
  );

  Future<void> login(WidgetTester t, String email) async {
    await t.enterText(find.byType(TextFormField).at(0), email);
    await t.enterText(find.byType(TextFormField).at(1), 'password');
    await t.tap(find.text('Log In'));
    await settle(t);
  }

  Future<void> logout(WidgetTester t) async {
    await t.tap(find.text('Profile').last);
    await settle(t);
    await t.scrollUntilVisible(find.text('Log Out'), 200);
    await t.tap(find.text('Log Out'));
    await settle(t);
    expect(find.text('Log In'), findsOneWidget);
  }

  setUp(() async => SharedPreferences.setMockInitialValues({}));

  testWidgets('wrong password shows an error', (t) async {
    app.main();
    await settle(t);
    await t.enterText(find.byType(TextFormField).at(0), 'alice@tasknest.test');
    await t.enterText(find.byType(TextFormField).at(1), 'nope-nope');
    await t.tap(find.text('Log In'));
    await settle(t);
    expect(find.text('Log In'), findsOneWidget);
    expect(find.textContaining('credentials'), findsWidgets);
  });

  testWidgets('member: dashboard, no FAB, role hidden, calendar, logout', (
    t,
  ) async {
    app.main();
    await settle(t);
    await login(t, 'alice@tasknest.test');
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.textContaining('Welcome back'), findsOneWidget);
    expect(find.byTooltip('New project'), findsNothing);
    // Role chip must not show the account role, only the designation.
    expect(find.text('Member'), findsNothing);
    expect(find.text('Senior Developer'), findsWidgets);

    await t.tap(find.text('My Tasks').last);
    await settle(t);
    await t.tap(find.byTooltip('Calendar'));
    await settle(t);
    expect(find.text('Calendar'), findsWidgets);
    await t.pageBack();
    await settle(t);
    await logout(t);
  });

  testWidgets('director: create project + task, theme toggle, admin users', (
    t,
  ) async {
    app.main();
    await settle(t);
    await login(t, 'director@tasknest.test');
    expect(find.byTooltip('New project'), findsOneWidget);

    await t.tap(find.byTooltip('New project'));
    await settle(t);
    final name = 'Phone QA ${DateTime.now().millisecondsSinceEpoch % 100000}';
    await t.enterText(find.byType(TextFormField).first, name);
    await t.tap(find.text('Create Project'));
    await settle(t);
    // Lands on the new project's detail screen.
    expect(find.text(name), findsWidgets);

    await t.enterText(find.byType(TextField).first, 'First phone task');
    await t.testTextInput.receiveAction(TextInputAction.done);
    await settle(t);
    expect(find.text('First phone task'), findsWidgets);
    await t.pageBack();
    await settle(t);

    // Theme toggle persists in the UI.
    await t.tap(find.text('Profile').last);
    await settle(t);
    await t.tap(find.text('Dark'));
    await settle(t);
    final ctx = t.element(find.byType(Scaffold).first);
    expect(Theme.of(ctx).brightness, Brightness.dark);
    await t.tap(find.text('Light'));
    await settle(t);

    await t.scrollUntilVisible(find.text('Manage users'), 200);
    await t.tap(find.text('Manage users'));
    await settle(t);
    expect(find.text('Alice Nguyen'), findsWidgets);
    await t.pageBack();
    await settle(t);
    await logout(t);
  });

  testWidgets('session survives restart', (t) async {
    app.main();
    await settle(t);
    await login(t, 'bob@tasknest.test');
    app.main();
    await settle(t);
    expect(find.text('Dashboard'), findsWidgets);
    await logout(t);
  });
}
