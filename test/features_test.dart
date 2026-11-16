import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tasknest_app/models/task.dart';
import 'package:tasknest_app/services/api_client.dart';
import 'package:tasknest_app/utils/time_format.dart';
import 'package:tasknest_app/widgets/board_view.dart';
import 'package:tasknest_app/widgets/comment_composer.dart';

TaskItem _task(int id, String status, {String? due}) => TaskItem(
  id: id,
  title: 'A fairly long task title number $id that should wrap nicely',
  status: status,
  priority: 'high',
  projectId: 1,
  dueDate: due,
);

void main() {
  test('relativeTime formats buckets', () {
    final now = DateTime(2026, 1, 10, 12);
    expect(relativeTime(now.subtract(const Duration(seconds: 5)), now: now), 'just now');
    expect(relativeTime(now.subtract(const Duration(minutes: 5)), now: now), '5m ago');
    expect(relativeTime(now.subtract(const Duration(hours: 3)), now: now), '3h ago');
    expect(relativeTime(now.subtract(const Duration(days: 2)), now: now), '2d ago');
  });

  test('API error mapper: 429 reads Retry-After, 422 maps fields', () async {
    SharedPreferences.setMockInitialValues({});
    ApiClient.resetCacheForTests();
    Future<ApiException> call(http.Response r) => http.runWithClient(
      () async {
        try {
          await ApiClient.get('/x');
        } on ApiException catch (e) {
          return e;
        }
        throw StateError('no error');
      },
      () => MockClient((_) async => r),
    );

    final e429 = await call(http.Response('{"message":"x"}', 429, headers: {'retry-after': '42'}));
    expect(e429.retryAfter, 42);
    expect(e429.message, 'Too many attempts. Try again in 42 seconds.');

    final e422 = await call(http.Response(
      jsonEncode({'message': 'bad', 'errors': {'name': ['Name is required']}}),
      422,
    ));
    expect(e422.fieldErrors['name'], 'Name is required');
  });

  testWidgets('comment composer: blank is rejected, valid text is trimmed and sent', (tester) async {
    final sent = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: CommentComposer(onSend: (b) async => sent.add(b))),
    ));
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    expect(find.text('Write a comment first'), findsOneWidget);
    expect(sent, isEmpty);

    await tester.enterText(find.byType(TextField), '   ');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();
    expect(sent, isEmpty);

    await tester.enterText(find.byType(TextField), '  hello  ');
    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();
    expect(sent, ['hello']);
  });

  for (final w in [320.0, 600.0, 1200.0]) {
    testWidgets('board lays out at ${w}px with text scale 2.0 without overflow', (tester) async {
      tester.view.physicalSize = Size(w, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: Size(w, 900), textScaler: const TextScaler.linear(2.0)),
          child: Scaffold(
            body: SizedBox(
              height: 700,
              child: BoardView(
                tasks: [_task(1, 'todo', due: '2020-01-01'), _task(2, 'in_progress'), _task(3, 'done')],
                canMove: true,
                onMove: (_, _) {},
                onOpen: (_) {},
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('To Do'), findsOneWidget);
    });
  }

  testWidgets('dragging a card to another column reports the new status', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? moved;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BoardView(
          tasks: [TaskItem(id: 1, title: 'Move me', status: 'todo', priority: 'low', projectId: 1)],
          canMove: true,
          onMove: (t, s) => moved = s,
          onOpen: (_) {},
        ),
      ),
    ));
    final from = tester.getCenter(find.text('Move me'));
    final to = tester.getCenter(find.text('Done'));
    final g = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 600));
    await g.moveTo(to);
    await tester.pump();
    await g.up();
    await tester.pumpAndSettle();
    expect(moved, 'done');
  });
}
