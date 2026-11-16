import 'package:flutter/material.dart';

import '../models/task.dart';
import '../services/api_client.dart';
import '../services/task_service.dart';

/// Turns any thrown error into a short, user-friendly sentence.
String friendlyError(Object e) {
  if (e is ApiException) return e.message;
  return 'Could not reach the server. Check your connection and try again.';
}

/// Single place for snackbar feedback so every screen behaves the same.
void showSnack(BuildContext context, String message, {SnackBarAction? action}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(content: Text(message), action: action));
}

/// 1-tap complete / reopen with an Undo action.
Future<void> toggleTaskDone(
  BuildContext context,
  TaskItem task,
  bool done,
  Future<void> Function() reload,
) async {
  final previous = task.status;
  final next = done ? StatusOptions.done : StatusOptions.todo;
  try {
    await TaskService.updateStatus(id: task.id, status: next);
    await reload();
    if (!context.mounted) return;
    showSnack(
      context,
      done ? 'Marked as done' : 'Moved back to To Do',
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () async {
          try {
            await TaskService.updateStatus(id: task.id, status: previous);
            await reload();
          } catch (_) {}
        },
      ),
    );
  } catch (e) {
    if (context.mounted) showSnack(context, friendlyError(e));
  }
}
