import '../core/theme/brand_colors.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/task.dart';
import 'status_priority_chips.dart';

/// One task card. Shows a completion checkbox (1-tap done), overdue state,
/// and optional assignee / project name.
class TaskRow extends StatelessWidget {
  final TaskItem task;
  final bool canOpen;
  final bool canToggle;
  final bool selectMode;
  final bool selected;
  final bool showAssignee;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final void Function(bool done)? onToggleDone;
  final VoidCallback? onDelete;

  const TaskRow({
    super.key,
    required this.task,
    this.canOpen = true,
    this.canToggle = false,
    this.selectMode = false,
    this.selected = false,
    this.showAssignee = true,
    this.onTap,
    this.onLongPress,
    this.onToggleDone,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final done = task.status == StatusOptions.done;
    final overdue = task.isOverdue;
    final dateFormat = DateFormat('MMM d');
    final due = task.due;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: selected ? scheme.primary.withValues(alpha: 0.08) : null,
      child: InkWell(
        onTap: selectMode || canOpen ? onTap : null,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 10, 10, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectMode)
                Checkbox(value: selected, onChanged: (_) => onTap?.call())
              else if (canToggle && onToggleDone != null)
                Semantics(
                  label: done
                      ? 'Mark "${task.title}" as not done'
                      : 'Mark "${task.title}" as done',
                  child: Tooltip(
                    message: done ? 'Mark as to do' : 'Mark as done',
                    child: Checkbox(
                      value: done,
                      shape: const CircleBorder(),
                      onChanged: (v) => onToggleDone!(v ?? false),
                    ),
                  ),
                )
              else
                const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        task.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          decoration: done ? TextDecoration.lineThrough : null,
                          color: done ? scheme.onSurfaceVariant : null,
                        ),
                      ),
                    ),
                    if (!showAssignee && task.projectName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        task.projectName!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        PriorityChip(priority: task.priority),
                        if (overdue) const OverdueChip(),
                        if (showAssignee && task.assignee != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InitialsAvatar(
                                name: task.assignee!.name,
                                avatarUrl: task.assignee!.avatarUrl,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                task.assignee!.name,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        if (due != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.event_outlined,
                                size: 14,
                                color: overdue
                                    ? AppColors.danger
                                    : scheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                dateFormat.format(due),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: overdue ? AppColors.danger : null,
                                  fontWeight: overdue ? FontWeight.w700 : null,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (onDelete != null && !selectMode)
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete task',
                  onPressed: onDelete,
                )
              else if (canOpen && !selectMode)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Icon(Icons.chevron_right),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A status group (To Do / In Progress / Done) of [TaskRow]s.
class TaskStatusColumn extends StatelessWidget {
  final String status;
  final List<TaskItem> tasks;
  final Widget Function(TaskItem) rowBuilder;

  const TaskStatusColumn({
    super.key,
    required this.status,
    required this.tasks,
    required this.rowBuilder,
  });

  @override
  Widget build(BuildContext context) {
    final accent = StatusChip.colorFor(status);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              children: [
                StatusChip(status: status),
                const SizedBox(width: 8),
                Text(
                  '${tasks.length}',
                  style: TextStyle(color: accent, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 6, top: 4, bottom: 10),
              child: Text(
                'No tasks',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            )
          else
            ...tasks.map(rowBuilder),
        ],
      ),
    );
  }
}

/// Search box + status chips (+ optional assignee picker).
class TaskFilterBar extends StatefulWidget {
  final String query;
  final String? status;
  final int? assigneeId;
  final List<MapEntry<int, String>> assignees;
  final ValueChanged<String> onQuery;
  final ValueChanged<String?> onStatus;
  final ValueChanged<int?>? onAssignee;

  const TaskFilterBar({
    super.key,
    required this.query,
    required this.status,
    required this.onQuery,
    required this.onStatus,
    this.assigneeId,
    this.assignees = const [],
    this.onAssignee,
  });

  @override
  State<TaskFilterBar> createState() => _TaskFilterBarState();
}

class _TaskFilterBarState extends State<TaskFilterBar> {
  late final TextEditingController _c = TextEditingController(
    text: widget.query,
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _c,
          textInputAction: TextInputAction.search,
          onChanged: widget.onQuery,
          decoration: InputDecoration(
            hintText: 'Search tasks',
            isDense: true,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _c.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _c.clear();
                      widget.onQuery('');
                      setState(() {});
                    },
                  ),
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final entry in <MapEntry<String?, String>>[
                const MapEntry(null, 'All'),
                ...StatusOptions.all.map(
                  (s) => MapEntry<String?, String>(s, StatusOptions.label(s)),
                ),
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(entry.value),
                    selected: widget.status == entry.key,
                    onSelected: (_) => widget.onStatus(entry.key),
                  ),
                ),
              if (widget.onAssignee != null && widget.assignees.isNotEmpty)
                PopupMenuButton<int?>(
                  tooltip: 'Filter by assignee',
                  onSelected: widget.onAssignee,
                  itemBuilder: (_) => [
                    const PopupMenuItem<int?>(
                      value: null,
                      child: Text('Anyone'),
                    ),
                    ...widget.assignees.map(
                      (a) => PopupMenuItem<int?>(
                        value: a.key,
                        child: Text(a.value),
                      ),
                    ),
                  ],
                  child: Chip(
                    avatar: const Icon(Icons.person_outline, size: 16),
                    label: Text(
                      widget.assigneeId == null
                          ? 'Assignee'
                          : widget.assignees
                                .firstWhere(
                                  (a) => a.key == widget.assigneeId,
                                  orElse: () => const MapEntry(0, 'Assignee'),
                                )
                                .value,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
