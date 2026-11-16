import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tasknest_app/models/task.dart';
import 'package:tasknest_app/utils/validators.dart';
import 'package:tasknest_app/widgets/status_priority_chips.dart';
import 'package:tasknest_app/widgets/task_row.dart';

TaskItem _task({String status = 'todo', String? due}) => TaskItem(
  id: 1,
  title: 'Write report',
  status: status,
  priority: 'medium',
  dueDate: due,
  projectId: 1,
);

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

void main() {
  group('Validators', () {
    test('email', () {
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('bad'), isNotNull);
      expect(Validators.email('a@b'), isNotNull);
      expect(Validators.email(' a@b.co '), isNull);
    });
    test('password needs 8 chars', () {
      expect(Validators.newPassword('1234567'), isNotNull);
      expect(Validators.newPassword('12345678'), isNull);
    });
    test('whitespace-only counts as empty', () {
      expect(Validators.required('   ', 'Name'), isNotNull);
    });
    test('title max length', () {
      expect(Validators.requiredMax('a' * 256, 'Title', 255), isNotNull);
      expect(Validators.requiredMax('a' * 255, 'Title', 255), isNull);
    });
  });

  group('TaskItem.isOverdue', () {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    test('past and open is overdue', () {
      expect(_task(due: _ymd(yesterday)).isOverdue, isTrue);
    });
    test('done is never overdue', () {
      expect(_task(status: 'done', due: _ymd(yesterday)).isOverdue, isFalse);
    });
    test('future or no date is not overdue', () {
      expect(_task(due: _ymd(tomorrow)).isOverdue, isFalse);
      expect(_task().isOverdue, isFalse);
    });
  });

  group('Widgets', () {
    testWidgets('InitialsAvatar shows name initials', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: InitialsAvatar(name: 'Alice Nguyen')),
      );
      expect(find.text('AN'), findsOneWidget);
    });

    testWidgets('TaskRow shows Overdue chip and toggles done', (tester) async {
      bool? toggled;
      final yesterday = DateTime.now().subtract(const Duration(days: 2));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaskRow(
              task: _task(due: _ymd(yesterday)),
              canToggle: true,
              onToggleDone: (v) => toggled = v,
            ),
          ),
        ),
      );
      expect(find.text('Overdue'), findsOneWidget);
      await tester.tap(find.byType(Checkbox));
      expect(toggled, isTrue);
    });
  });
}
