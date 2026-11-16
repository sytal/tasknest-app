import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tasknest_app/core/layout/responsive.dart';
import 'package:tasknest_app/core/widgets/brand_logo.dart';
import 'package:tasknest_app/screens/login_screen.dart';
import 'package:tasknest_app/services/session.dart';

void main() {
  test('size classes follow the breakpoints', () {
    expect(sizeClassFor(320), SizeClass.compact);
    expect(sizeClassFor(599), SizeClass.compact);
    expect(sizeClassFor(600), SizeClass.medium);
    expect(sizeClassFor(839), SizeClass.medium);
    expect(sizeClassFor(840), SizeClass.expanded);
    expect(sizeClassFor(1199), SizeClass.expanded);
    expect(sizeClassFor(1200), SizeClass.large);
  });

  for (final w in [280.0, 320.0, 360.0, 600.0, 768.0, 1024.0, 1440.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('login has no overflow at ${w}px, text x$scale', (t) async {
        SharedPreferences.setMockInitialValues({});
        t.view.physicalSize = Size(w, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.reset);
        await t.pumpWidget(
          ChangeNotifierProvider(
            create: (_) => Session(),
            child: MaterialApp(
              builder: (c, child) => MediaQuery(
                data: MediaQuery.of(c)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: const LoginScreen(),
            ),
          ),
        );
        await t.pump();
        expect(t.takeException(), isNull);
        expect(find.bySemanticsLabel('TaskNest logo'), findsWidgets);
      });
    }
  }

  testWidgets('empty state shows message and action', (t) async {
    var tapped = false;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyState(
            message: 'Nothing here',
            actionLabel: 'Create',
            onAction: () => tapped = true,
          ),
        ),
      ),
    );
    expect(find.text('Nothing here'), findsOneWidget);
    await t.tap(find.text('Create'));
    expect(tapped, isTrue);
  });
}
