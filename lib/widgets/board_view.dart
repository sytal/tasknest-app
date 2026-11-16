import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/task.dart';
import 'status_priority_chips.dart';

/// Kanban board: To Do / In Progress / Done. Side by side on wide screens,
/// horizontally paged on phones. Long-press a card (touch) or drag it (mouse)
/// onto another column to change its status.
class BoardView extends StatelessWidget {
  final List<TaskItem> tasks;
  final bool canMove;
  final void Function(TaskItem task, String status) onMove;
  final void Function(TaskItem task) onOpen;

  const BoardView({
    super.key,
    required this.tasks,
    required this.canMove,
    required this.onMove,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 840;
    final columns = [
      for (final s in StatusOptions.all)
        _Column(
          status: s,
          tasks: tasks.where((t) => t.status == s).toList(),
          canMove: canMove,
          onMove: onMove,
          onOpen: onOpen,
        ),
    ];
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final c in columns) Expanded(child: c)],
      );
    }
    final w = MediaQuery.sizeOf(context).width * 0.82;
    return ListView(
      scrollDirection: Axis.horizontal,
      physics: const PageScrollPhysics(),
      children: [for (final c in columns) SizedBox(width: w.clamp(240, 360), child: c)],
    );
  }
}

class _Column extends StatelessWidget {
  final String status;
  final List<TaskItem> tasks;
  final bool canMove;
  final void Function(TaskItem, String) onMove;
  final void Function(TaskItem) onOpen;

  const _Column({
    required this.status,
    required this.tasks,
    required this.canMove,
    required this.onMove,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DragTarget<TaskItem>(
      onWillAcceptWithDetails: (d) => canMove && d.data.status != status,
      onAcceptWithDetails: (d) => onMove(d.data, status),
      builder: (context, candidate, _) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: candidate.isNotEmpty
              ? scheme.primary.withValues(alpha: 0.15)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 2, 4, 8),
              child: Row(children: [
                Expanded(child: Text(StatusOptions.label(status), style: Theme.of(context).textTheme.titleSmall)),
                Text('${tasks.length}', style: Theme.of(context).textTheme.labelLarge),
              ]),
            ),
            Expanded(
              child: tasks.isEmpty
                  ? Center(child: Text(canMove ? 'Drop tasks here' : 'No tasks', style: Theme.of(context).textTheme.bodySmall))
                  : ListView(children: [
                      for (final t in tasks)
                        canMove
                            ? LongPressDraggable<TaskItem>(
                                data: t,
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: SizedBox(width: 260, child: _Card(task: t, onOpen: () {})),
                                ),
                                childWhenDragging: Opacity(opacity: 0.3, child: _Card(task: t, onOpen: () {})),
                                child: _Card(task: t, onOpen: () => onOpen(t)),
                              )
                            : _Card(task: t, onOpen: () => onOpen(t)),
                    ]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final TaskItem task;
  final VoidCallback onOpen;
  const _Card({required this.task, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final due = task.due;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(task.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PriorityChip(priority: task.priority),
                if (task.subtasksCount > 0)
                  Text('${task.subtasksDoneCount}/${task.subtasksCount}', style: Theme.of(context).textTheme.labelSmall),
                if (task.assignee != null)
                  InitialsAvatar(name: task.assignee!.name, radius: 11, avatarUrl: task.assignee!.avatarUrl),
              ],
            ),
            if (due != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  Icon(Icons.event_outlined, size: 14, color: task.isOverdue ? scheme.error : null),
                  const SizedBox(width: 4),
                  Flexible(child: Text(
                    '${DateFormat('MMM d').format(due)}${task.isOverdue ? ' · Overdue' : ''}',
                    style: TextStyle(fontSize: 12, color: task.isOverdue ? scheme.error : null),
                  )),
                ]),
              ),
          ]),
        ),
      ),
    );
  }
}
