import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tasknest_app/core/theme/brand_colors.dart';
import 'package:tasknest_app/core/widgets/app_widgets.dart';
import 'package:tasknest_app/services/theme_controller.dart';
import 'package:tasknest_app/theme/app_theme.dart';

Widget _host(Widget child, {Size size = const Size(400, 800)}) => MediaQuery(
  data: MediaQueryData(size: size),
  child: MaterialApp(theme: AppTheme.light(), home: Scaffold(body: child)),
);

void main() {
  testWidgets('AppButton is disabled while loading', (t) async {
    var taps = 0;
    await t.pumpWidget(
      _host(AppButton(label: 'Go', loading: true, onPressed: () => taps++)),
    );
    await t.tap(find.byType(FilledButton));
    expect(taps, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('showConfirmDialog returns true on confirm', (t) async {
    bool? result;
    await t.pumpWidget(
      _host(
        Builder(
          builder: (c) => AppButton(
            label: 'Open',
            onPressed: () async => result = await showConfirmDialog(
              c,
              title: 'Sure?',
              confirmLabel: 'Yes',
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Open'));
    await t.pumpAndSettle();
    await t.tap(find.text('Yes'));
    await t.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('UserAvatar shows initials and is stable per name', (t) async {
    await t.pumpWidget(_host(const UserAvatar(name: 'Alice Brown')));
    expect(find.text('AB'), findsOneWidget);
    expect(
      AppColors.avatarIndex('Alice Brown'),
      AppColors.avatarIndex('Alice Brown'),
    );
  });

  testWidgets('TwoPane is side by side only when wide', (t) async {
    const a = SizedBox(key: Key('a'), height: 10);
    const b = SizedBox(key: Key('b'), height: 10);
    await t.pumpWidget(_host(const TwoPane(primary: a, secondary: b)));
    expect(
      t.getTopLeft(find.byKey(const Key('a'))).dy,
      lessThan(t.getTopLeft(find.byKey(const Key('b'))).dy),
    );
    await t.pumpWidget(
      _host(
        const TwoPane(primary: a, secondary: b),
        size: const Size(1200, 800),
      ),
    );
    expect(
      t.getTopLeft(find.byKey(const Key('a'))).dy,
      t.getTopLeft(find.byKey(const Key('b'))).dy,
    );
  });

  test('ThemeController persists the chosen mode', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ThemeController();
    await c.set(ThemeMode.dark);
    final c2 = ThemeController();
    await c2.load();
    expect(c2.mode, ThemeMode.dark);
  });

  test('no hard-coded colour literals outside brand_colors.dart', () {
    final bad = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('brand_colors.dart')) continue;
      if (RegExp(r'Color\(0x').hasMatch(f.readAsStringSync())) bad.add(f.path);
    }
    expect(bad, isEmpty);
  });
}
