import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../services/project_service.dart';
import '../services/session.dart';
import '../services/task_service.dart';
import '../widgets/app_card.dart';
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

  bool _selectMode = false;
  final Set<int> _selectedTaskIds = {};
  bool _bulkAssigning = false;

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

  void _toggleSelectMode() {
    setState(() {
      _selectMode = !_selectMode;
      if (!_selectMode) _selectedTaskIds.clear();
    });
  }

  void _toggleTaskSelected(TaskItem task) {
    setState(() {
      if (_selectedTaskIds.contains(task.id)) {
        _selectedTaskIds.remove(task.id);
      } else {
        _selectedTaskIds.add(task.id);
      }
    });
  }

  Future<void> _openBulkAssignSheet() async {
    final project = _project;
    if (project == null || _selectedTaskIds.isEmpty) return;
    final members = project.members;
    final selected = <int>{};

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assign ${_selectedTaskIds.length} task${_selectedTaskIds.length == 1 ? '' : 's'}',
                      style: Theme.of(sheetContext).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select 1 member to assign all tasks to them, or select '
                      'multiple to split the tasks evenly between them.',
                      style: Theme.of(sheetContext).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    if (members.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('This project has no members to assign to.'),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 360),
                        child: ListView(
                          shrinkWrap: true,
                          children: members.map((m) {
                            final checked = selected.contains(m.id);
                            return CheckboxListTile(
                              value: checked,
                              onChanged: (value) {
                                setSheetState(() {
                                  if (value == true) {
                                    selected.add(m.id);
                                  } else {
                                    selected.remove(m.id);
                                  }
                                });
                              },
                              secondary: InitialsAvatar(
                                name: m.name,
                                avatarUrl: m.avatarUrl,
                              ),
                              title: Text(m.name),
                              subtitle: m.designation != null ? Text(m.designation!) : null,
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(sheetContext).pop(false),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton(
                            onPressed: selected.isEmpty
                                ? null
                                : () => Navigator.of(sheetContext).pop(true),
                            child: const Text('Assign'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (confirmed == true && selected.isNotEmpty) {
      await _bulkAssign(selected.toList());
    }
  }

  Future<void> _bulkAssign(List<int> assigneeIds) async {
    final project = _project;
    if (project == null) return;
    setState(() => _bulkAssigning = true);
    try {
      await TaskService.bulkAssign(
        projectId: project.id,
        taskIds: _selectedTaskIds.toList(),
        assigneeIds: assigneeIds,
      );
      setState(() {
        _selectMode = false;
        _selectedTaskIds.clear();
      });
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Tasks assigned.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to assign tasks: $e')));
      }
    } finally {
      if (mounted) setState(() => _bulkAssigning = false);
    }
  }

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
        title: Text(_selectMode ? '${_selectedTaskIds.length} selected' : project.name),
        leading: _selectMode
            ? IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cancel selection',
                onPressed: _toggleSelectMode,
              )
            : null,
        actions: isManager
            ? [
                if (!_selectMode)
                  IconButton(
                    icon: const Icon(Icons.playlist_add_check),
                    tooltip: 'Select tasks to assign',
                    onPressed: _toggleSelectMode,
                  ),
                if (!_selectMode) ...[
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
                ],
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
            SectionHeader(
              title: 'Members',
              icon: Icons.group_outlined,
              trailing: isManager
                  ? FilledButton.icon(
                      onPressed: () async {
                        final changed = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => ManageMembersScreen(project: project),
                          ),
                        );
                        if (changed == true) _load();
                      },
                      icon: const Icon(Icons.manage_accounts_outlined, size: 18),
                      label: const Text('Manage'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                    )
                  : null,
            ),
            if (project.members.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  isManager
                      ? 'No members yet. Tap Manage above to add some.'
                      : 'No members yet.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            else
              ...project.members.map(
                (m) => AppCard(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: m.avatarUrl != null && m.avatarUrl!.isNotEmpty
                        ? CircleAvatar(backgroundImage: NetworkImage(m.avatarUrl!))
                        : CircleAvatar(
                            backgroundColor: m.isLead
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.secondary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            child: Text(m.isLead ? 'L' : 'M'),
                          ),
                    title: Text(m.name),
                    subtitle: Text(m.designation ?? ''),
                    trailing: m.isLead ? const RoleBadge(label: 'LEAD') : null,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            SectionHeader(title: 'Tasks', icon: Icons.task_alt_outlined),
            ...StatusOptions.all.map((status) => _StatusColumn(
                  status: status,
                  tasks: _byStatus(status),
                  isManager: isManager,
                  currentUserId: user?.id,
                  selectMode: _selectMode,
                  selectedTaskIds: _selectedTaskIds,
                  onTap: (task) async {
                    if (_selectMode) {
                      _toggleTaskSelected(task);
                      return;
                    }
                    final canOpen = isManager || task.assignee?.id == user?.id;
                    if (!canOpen) return;
                    final changed = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => TaskEditScreen(project: project, task: task),
                      ),
                    );
                    if (changed == true) _load();
                  },
                  onLongPress: isManager
                      ? (task) {
                          if (!_selectMode) {
                            setState(() => _selectMode = true);
                          }
                          _toggleTaskSelected(task);
                        }
                      : null,
                  onDelete: isManager && !_selectMode ? _deleteTask : null,
                )),
          ],
        ),
      ),
      floatingActionButton: !_selectMode && isManager
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
      bottomNavigationBar: _selectMode && _selectedTaskIds.isNotEmpty
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, -2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Text(
                      '${_selectedTaskIds.length} selected',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _bulkAssigning ? null : _openBulkAssignSheet,
                      icon: _bulkAssigning
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.person_add_alt_1_outlined, size: 18),
                      label: const Text('Assign'),
                    ),
                  ],
                ),
              ),
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
  final bool selectMode;
  final Set<int> selectedTaskIds;
  final void Function(TaskItem) onTap;
  final void Function(TaskItem)? onLongPress;
  final void Function(TaskItem)? onDelete;

  const _StatusColumn({
    required this.status,
    required this.tasks,
    required this.isManager,
    required this.currentUserId,
    this.selectMode = false,
    this.selectedTaskIds = const {},
    required this.onTap,
    this.onLongPress,
    this.onDelete,
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
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w700,
                  ),
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
            ...tasks.map((task) {
              final canOpen = isManager || task.assignee?.id == currentUserId;
              final isSelected = selectedTaskIds.contains(task.id);
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: isSelected
                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
                    : null,
                child: InkWell(
                  onTap: selectMode ? () => onTap(task) : (canOpen ? () => onTap(task) : null),
                  onLongPress: onLongPress != null ? () => onLongPress!(task) : null,
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (selectMode)
                          Padding(
                            padding: const EdgeInsets.only(right: 4),
                            child: Checkbox(
                              value: isSelected,
                              onChanged: (_) => onTap(task),
                            ),
                          ),
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
                                        InitialsAvatar(
                                          name: task.assignee!.name,
                                          avatarUrl: task.assignee!.avatarUrl,
                                        ),
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
                        if (onDelete != null)
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => onDelete!(task),
                          )
                        else if (canOpen)
                          const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
