import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../services/project_service.dart';
import '../services/session.dart';
import '../services/task_service.dart';
import '../widgets/loading_view.dart';
import '../widgets/status_priority_chips.dart';
import 'task_edit_screen.dart';

/// "My Tasks" tab: every task assigned to the current user across all of
/// their projects, grouped into To Do / In Progress / Done columns the same
/// way [ProjectDetailScreen] presents a single project's Kanban board.
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
      final userId = context.read<Session>().currentUser?.id;
      final results = await Future.wait([
        TaskService.list(assignee: userId),
        ProjectService.list(),
      ]);
      setState(() {
        _tasks = results[0] as List<TaskItem>;
        _projects = results[1] as List<Project>;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<TaskItem> _byStatus(String status) =>
      _tasks.where((t) => t.status == status).toList();

  Future<void> _openTask(TaskItem task) async {
    final match = _projects.where((p) => p.id == task.projectId).toList();
    final project = match.isNotEmpty
        ? match.first
        : Project(id: task.projectId, name: task.projectName ?? 'Project', members: const []);
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TaskEditScreen(project: project, task: task),
      ),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const LoadingView();
    }
    if (_error != null) {
      return ErrorView(message: 'Failed to load your tasks.\n$_error', onRetry: _load);
    }
    if (_tasks.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Center(child: Text('No tasks assigned to you yet.')),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(12),
        children: StatusOptions.all
            .map((status) => _StatusColumn(
                  status: status,
                  tasks: _byStatus(status),
                  onTap: _openTask,
                ))
            .toList(),
      ),
    );
  }
}

class _StatusColumn extends StatelessWidget {
  final String status;
  final List<TaskItem> tasks;
  final void Function(TaskItem) onTap;

  const _StatusColumn({
    required this.status,
    required this.tasks,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d');
    final accent = StatusChip.colorFor(status);
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
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
            )
          else
            ...tasks.map((task) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: InkWell(
                    onTap: () => onTap(task),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.title,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 15,
                                  ),
                                ),
                                if (task.projectName != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    task.projectName!,
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: Theme.of(context).colorScheme.outline,
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
                                    if (task.assignee != null)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          InitialsAvatar(name: task.assignee!.name),
                                          const SizedBox(width: 6),
                                          Text(
                                            task.assignee!.name,
                                            style: Theme.of(context).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    if (task.dueDate != null)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.event_outlined,
                                            size: 14,
                                            color: Theme.of(context).colorScheme.outline,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            dateFormat.format(
                                              DateTime.tryParse(task.dueDate!) ?? DateTime.now(),
                                            ),
                                            style: Theme.of(context).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                )),
        ],
      ),
    );
  }
}
