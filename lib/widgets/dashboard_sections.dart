import "../core/layout/responsive.dart";

import 'package:flutter/material.dart';

import '../models/collab.dart';
import '../models/task.dart';
import '../screens/my_tasks_screen.dart';
import '../screens/task_detail_screen.dart';
import '../services/collab_service.dart';
import '../utils/feedback.dart';
import '../utils/time_format.dart';
import 'app_card.dart';

/// Dashboard v2: tasks due soon, recent activity and (director/CEO) workload.
/// One request to GET /api/dashboard; has its own skeleton, empty and retry states.
class DashboardSections extends StatefulWidget {
  final bool showWorkload;
  const DashboardSections({super.key, required this.showWorkload});

  @override
  State<DashboardSections> createState() => _DashboardSectionsState();
}

class _DashboardSectionsState extends State<DashboardSections> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final d = await CollabService.dashboard();
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _skeleton(BuildContext context) {
    final c = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Column(
      children: [
        for (var i = 0; i < 2; i++)
          Container(
            height: 90,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: _loading
          ? _skeleton(context)
          : _error != null
          ? AppCard(
              child: Row(
                children: [
                  const Icon(Icons.cloud_off_outlined),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_error!)),
                  TextButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          : _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final d = _data!;
    final due = ((d['my_due_soon'] as List?) ?? [])
        .map((e) => TaskItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final activity = ((d['recent_activity'] as List?) ?? [])
        .map((e) => ActivityItem.fromJson(e as Map<String, dynamic>))
        .toList();
    final workload = ((d['workload'] as List?) ?? [])
        .map((e) => WorkloadItem(e['name'].toString(), e['open_tasks'] as int))
        .toList();
    final maxLoad = workload.fold<int>(
      1,
      (m, w) => w.openTasks > m ? w.openTasks : m,
    );
    final dueBlock = <Widget>[
      SectionHeader(
        title: 'Due this week',
        icon: Icons.event_available_outlined,
        trailing: TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => Scaffold(
                appBar: AppBar(title: const Text('My Tasks')),
                body: const MyTasksScreen(),
              ),
            ),
          ),
          child: const Text('See all'),
        ),
      ),
      if (due.isEmpty)
        AppCard(
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  "You're all caught up. Nothing due in the next 7 days.",
                ),
              ),
            ],
          ),
        )
      else
        for (final t in due)
          AppCard(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: EdgeInsets.zero,
            child: ListTile(
              dense: true,
              leading: Icon(
                t.isOverdue ? Icons.warning_amber : Icons.task_alt,
                color: t.isOverdue ? Theme.of(context).colorScheme.error : null,
              ),
              title: Text(
                t.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text('${t.projectName ?? ''} · due ${t.dueDate ?? ''}'),
              onTap: () async {
                await openTaskDetail(context, t, null);
                _load();
              },
            ),
          ),
    ];
    final actBlock = <Widget>[
      const SectionHeader(title: 'Recently updated', icon: Icons.history),
      if (activity.isEmpty)
        const AppCard(child: Text('No recent activity yet.'))
      else
        for (final a in activity)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.circle, size: 8),
            title: Text(a.message),
            subtitle: Text(relativeTime(a.createdAt)),
          ),
    ];
    final workBlock = <Widget>[
      const SizedBox(height: 12),
      const SectionHeader(title: 'Team workload', icon: Icons.bar_chart),
      if (workload.isEmpty) const Text('No workload data.'),
      for (final w in workload)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              SizedBox(
                width: 110,
                child: Text(w.name, overflow: TextOverflow.ellipsis),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: w.openTasks / maxLoad,
                    minHeight: 8,
                  ),
                ),
              ),
              SizedBox(
                width: 32,
                child: Text('${w.openTasks}', textAlign: TextAlign.right),
              ),
            ],
          ),
        ),
    ];
    Widget col(List<Widget> c) =>
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: c);
    if (context.isWide && widget.showWorkload) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: col([...dueBlock, const SizedBox(height: 12), ...actBlock]),
          ),
          const SizedBox(width: Space.xl),
          Expanded(flex: 2, child: col(workBlock)),
        ],
      );
    }
    return col([
      ...dueBlock,
      const SizedBox(height: 12),
      ...actBlock,
      if (widget.showWorkload) ...[const SizedBox(height: 12), ...workBlock],
    ]);
  }
}
