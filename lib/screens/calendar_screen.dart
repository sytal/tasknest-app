import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/layout/responsive.dart';
import '../core/widgets/brand_logo.dart';
import '../models/task.dart';
import '../services/collab_service.dart';
import '../utils/feedback.dart';
import '../widgets/loading_view.dart';
import '../widgets/status_priority_chips.dart';
import 'task_detail_screen.dart';

/// Month view of my tasks by due date. Dots mark due days; red when overdue.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _month;
  DateTime? _selected;
  List<TaskItem> _tasks = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final n = DateTime.now();
    _month = DateTime(n.year, n.month);
    _selected = DateTime(n.year, n.month, n.day);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final t = await CollabService.tasksDue(
        _month,
        DateTime(_month.year, _month.month + 1, 0),
      );
      if (mounted)
        setState(() {
          _tasks = t;
          _error = null;
        });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _shift(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _selected = null;
    });
    _load();
  }

  List<TaskItem> _on(DateTime d) => _tasks
      .where((t) => t.due != null && DateUtils.isSameDay(t.due, d))
      .toList();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final first = DateTime(_month.year, _month.month, 1);
    final days = DateUtils.getDaysInMonth(_month.year, _month.month);
    final offset = (first.weekday + 6) % 7; // Monday first
    final today = DateUtils.dateOnly(DateTime.now());
    final dayTasks = _selected == null ? <TaskItem>[] : _on(_selected!);

    final calendar = <Widget>[
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            tooltip: 'Previous month',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _shift(-1),
          ),
          Text(
            DateFormat('MMMM y').format(_month),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          IconButton(
            tooltip: 'Next month',
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _shift(1),
          ),
        ],
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            for (final d in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(
                child: Center(
                  child: Text(d, style: Theme.of(context).textTheme.labelSmall),
                ),
              ),
          ],
        ),
      ),
      if (_loading) const LinearProgressIndicator(),
      Padding(
        padding: const EdgeInsets.all(12),
        child: GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var i = 0; i < offset; i++) const SizedBox.shrink(),
            for (var day = 1; day <= days; day++)
              Builder(
                builder: (context) {
                  final date = DateTime(_month.year, _month.month, day);
                  final ts = _on(date);
                  final overdue = ts.any((t) => t.isOverdue);
                  final sel =
                      _selected != null && DateUtils.isSameDay(_selected, date);
                  return Semantics(
                    label:
                        '${DateFormat('MMMM d').format(date)}, ${ts.length} tasks due',
                    button: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _selected = date),
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: sel
                              ? scheme.primary.withValues(alpha: 0.2)
                              : null,
                          border: DateUtils.isSameDay(date, today)
                              ? Border.all(color: scheme.primary)
                              : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('$day'),
                            if (ts.isNotEmpty)
                              Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.only(top: 2),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: overdue
                                      ? scheme.error
                                      : scheme.primary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    ];
    final wide = context.isWide;
    return Scaffold(
      appBar: AppBar(title: const Text('Calendar')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: wide ? 1100 : 560),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(width: 480, child: Column(children: calendar)),
                    const VerticalDivider(width: 1),
                    Expanded(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(Space.lg),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _selected == null
                                    ? 'Select a day'
                                    : DateFormat('EEEE, MMMM d')
                                          .format(_selected!),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                          ),
                          Expanded(
                            child: _error != null
                                ? ErrorView(message: _error!, onRetry: _load)
                                : dayTasks.isEmpty
                                ? const EmptyState(
                                    message: 'No tasks due this day. Enjoy the free time!',
                                  )
                                : ListView(
                                    children: [
                                      for (final t in dayTasks)
                                        ListTile(
                                          leading: Icon(
                                            t.isOverdue
                                                ? Icons.warning_amber
                                                : Icons.task_alt,
                                            color: t.isOverdue
                                                ? scheme.error
                                                : null,
                                          ),
                                          title: Text(t.title),
                                          subtitle: Text(
                                            '${t.projectName ?? ''}${t.isOverdue ? ' · Overdue' : ''}',
                                          ),
                                          trailing: StatusChip(
                                            status: t.status,
                                          ),
                                          onTap: () async {
                                            await openTaskDetail(
                                              context,
                                              t,
                                              null,
                                            );
                                            _load();
                                          },
                                        ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    ...calendar,
                    const Divider(height: 1),
                    Expanded(
                      child: _error != null
                          ? ErrorView(message: _error!, onRetry: _load)
                          : dayTasks.isEmpty
                          ? const EmptyState(
                              message:
                                  'No tasks due this day. Enjoy the free time!',
                            )
                          : ListView(
                              children: [
                                for (final t in dayTasks)
                                  ListTile(
                                    leading: Icon(
                                      t.isOverdue
                                          ? Icons.warning_amber
                                          : Icons.task_alt,
                                      color: t.isOverdue ? scheme.error : null,
                                    ),
                                    title: Text(t.title),
                                    subtitle: Text(
                                      '${t.projectName ?? ''}${t.isOverdue ? ' · Overdue' : ''}',
                                    ),
                                    trailing: StatusChip(status: t.status),
                                    onTap: () async {
                                      await openTaskDetail(context, t, null);
                                      _load();
                                    },
                                  ),
                              ],
                            ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
