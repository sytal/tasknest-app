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
import 'manage_members_screen.dart';
import 'project_edit_screen.dart';
import 'task_edit_screen.dart';

class ProjectDetailScreen extends StatefulWidget {
  final int projectId;

  const ProjectDetailScreen({super.key, required this.projectId});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  Project? _project;
  List<TaskItem> _tasks = [];
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
      final projects = await ProjectService.list();
      final match = projects.where((p) => p.id == widget.projectId).toList();
      if (match.isEmpty) {
        throw Exception('Project not found or you do not have access.');
      }
      final tasks = await TaskService.list(projectId: widget.projectId);
      setState(() {
        _project = match.first;
        _tasks = tasks;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteProject() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete project?'),
        content: const Text('This will permanently delete the project and its tasks.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && _project != null) {
      try {
        await ProjectService.delete(_project!.id);
        if (mounted) Navigator.of(context).pop();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
        }
      }
    }
  }

  Future<void> _deleteTask(TaskItem task) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await TaskService.delete(task.id);
        _load();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Failed to delete task: $e')));
        }
      }
    }
  }

  List<TaskItem> _byStatus(String status) =>
      _tasks.where((t) => t.status == status).toList();

  @override
  Widget build(BuildContext context) {
    final user = context.watch<Session>().currentUser;
    final isManager = user?.isDirectorOrCeo ?? false;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Project')),
        body: const LoadingView(),
      );
    }
    if (_error != null || _project == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Project')),
        body: ErrorView(message: _error ?? 'Not found', onRetry: _load),
      );
    }

    final project = _project!;

    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
        actions: isManager
            ? [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit project',
                  onPressed: () async {
                    final updated = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => ProjectEditScreen(project: project),
                      ),
                    );
                    if (updated == true) _load();
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Delete project',
                  onPressed: _deleteProject,
                ),
              ]
            : null,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (project.description != null && project.description!.isNotEmpty) ...[
              Text(project.description!),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                Text('Members', style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                if (isManager)
                  TextButton.icon(
                    onPressed: () async {
                      final changed = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => ManageMembersScreen(project: project),
                        ),
                      );
                      if (changed == true) _load();
                    },
                    icon: const Icon(Icons.manage_accounts_outlined),
                    label: const Text('Manage'),
                  ),
              ],
            ),
            ...project.members.map(
              (m) => Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(child: Text(m.isLead ? 'L' : 'M')),
                  title: Text(m.name),
                  subtitle: Text(m.designation ?? ''),
                  trailing: m.isLead
                      ? const Chip(
                          label: Text('Lead', style: TextStyle(fontSize: 11)),
                          visualDensity: VisualDensity.compact,
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Tasks', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...StatusOptions.all.map((status) => _StatusColumn(
                  status: status,
                  tasks: _byStatus(status),
                  isManager: isManager,
                  currentUserId: user?.id,
                  onTap: (task) async {
                    final canOpen = isManager || task.assignee?.id == user?.id;
                    if (!canOpen) return;
                    final changed = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => TaskEditScreen(project: project, task: task),
                      ),
                    );
                    if (changed == true) _load();
                  },
                  onDelete: isManager ? _deleteTask : null,
                )),
          ],
        ),
      ),
      floatingActionButton: isManager
          ? FloatingActionButton(
              onPressed: () async {
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => TaskEditScreen(project: project),
                  ),
                );
                if (created == true) _load();
              },
              tooltip: 'New task',
              child: const Icon(Icons.add_task),
            )
          : null,
    );
  }
}

class _StatusColumn extends StatelessWidget {
  final String status;
  final List<TaskItem> tasks;
  final bool isManager;
  final int? currentUserId;
  final void Function(TaskItem) onTap;
  final void Function(TaskItem)? onDelete;

  const _StatusColumn({
    required this.status,
    required this.tasks,
    required this.isManager,
    required this.currentUserId,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM d');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              StatusChip(status: status),
              const SizedBox(width: 8),
              Text('(${tasks.length})'),
            ],
          ),
        ),
        if (tasks.isEmpty)
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 12),
            child: Text('No tasks', style: TextStyle(color: Colors.grey)),
          )
        else
          ...tasks.map((task) {
            final canOpen = isManager || task.assignee?.id == currentUserId;
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                enabled: canOpen,
                title: Text(task.title),
                subtitle: Row(
                  children: [
                    PriorityChip(priority: task.priority),
                    const SizedBox(width: 8),
                    if (task.assignee != null)
                      Text('Assignee: ${task.assignee!.name}'),
                    if (task.dueDate != null) ...[
                      const SizedBox(width: 8),
                      Text('Due ${dateFormat.format(DateTime.tryParse(task.dueDate!) ?? DateTime.now())}'),
                    ],
                  ],
                ),
                trailing: onDelete != null
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => onDelete!(task),
                      )
                    : (canOpen ? const Icon(Icons.chevron_right) : null),
                onTap: canOpen ? () => onTap(task) : null,
              ),
            );
          }),
        const SizedBox(height: 12),
      ],
    );
  }
}
