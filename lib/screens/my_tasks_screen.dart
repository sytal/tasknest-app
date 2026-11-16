import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../services/project_service.dart';
import '../services/session.dart';
import '../services/task_service.dart';
import '../utils/feedback.dart';
import '../widgets/loading_view.dart';
import '../widgets/task_row.dart';
import 'task_detail_screen.dart';

/// "My Tasks" tab: every task assigned to the current user across all of
/// their projects, grouped into To Do / In Progress / Done.
class MyTasksScreen extends StatefulWidget {
  const MyTasksScreen({super.key});

  @override
  State<MyTasksScreen> createState() => _MyTasksScreenState();
}

class _MyTasksScreenState extends State<MyTasksScreen> {
  List<TaskItem> _tasks = [];
  List<Project> _projects = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final userId = context.read<Session>().currentUser?.id;
      final results = await Future.wait([
        TaskService.list(assignee: userId),
        ProjectService.list(),
      ]);
      if (!mounted) return;
      setState(() {
        _tasks = results[0] as List<TaskItem>;
        _projects = results[1] as List<Project>;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<TaskItem> _byStatus(String status) {
    final q = _query.trim().toLowerCase();
    return _tasks
        .where(
          (t) =>
              t.status == status &&
              (q.isEmpty ||
                  t.title.toLowerCase().contains(q) ||
                  (t.projectName ?? '').toLowerCase().contains(q)),
        )
        .toList();
  }

  Future<void> _openTask(TaskItem task) async {
    final match = _projects.where((p) => p.id == task.projectId).toList();
    final project = match.isNotEmpty
        ? match.first
        : Project(
            id: task.projectId,
            name: task.projectName ?? 'Project',
            members: const [],
          );
    final changed = await openTaskDetail(context, task, project);
    if (changed == true) {
      await _load(silent: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    if (_tasks.isEmpty) {
      final scheme = Theme.of(context).colorScheme;
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Icon(Icons.task_alt, size: 56, color: scheme.primary),
            const SizedBox(height: 12),
            Text(
              "You're all caught up",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Tasks assigned to you will show up here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Center(
              child: OutlinedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ),
          ],
        ),
      );
    }
    final statuses = _statusFilter == null
        ? StatusOptions.all
        : [_statusFilter!];
    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            children: [
              TaskFilterBar(
                query: _query,
                status: _statusFilter,
                onQuery: (v) => setState(() => _query = v),
                onStatus: (v) => setState(() => _statusFilter = v),
              ),
              const SizedBox(height: 12),
              ...statuses.map(
                (status) => TaskStatusColumn(
                  status: status,
                  tasks: _byStatus(status),
                  rowBuilder: (task) => TaskRow(
                    task: task,
                    showAssignee: false,
                    canToggle: true,
                    onTap: () => _openTask(task),
                    onToggleDone: (done) => toggleTaskDone(
                      context,
                      task,
                      done,
                      () => _load(silent: true),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
