import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/collab_service.dart';
import '../widgets/board_view.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../services/api_client.dart';
import '../services/project_service.dart';
import '../services/session.dart';
import '../services/task_service.dart';
import '../widgets/app_card.dart';
import '../widgets/loading_view.dart';
import '../utils/feedback.dart';
import '../utils/validators.dart';
import '../widgets/status_priority_chips.dart';
import '../widgets/task_row.dart';
import 'manage_members_screen.dart';
import 'project_edit_screen.dart';
import 'task_detail_screen.dart';
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

  String _query = '';
  String? _statusFilter;
  int? _assigneeFilter;
  final _quickController = TextEditingController();
  int? _quickAssignee;
  bool _quickAdding = false;
  bool _board = false;
  int? _labelFilter;

  Future<void> _loadViewPref() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getBool('board_view_${widget.projectId}') ?? false;
      if (mounted) setState(() => _board = v);
    } catch (_) {}
  }

  Future<void> _setBoard(bool v) async {
    setState(() => _board = v);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('board_view_${widget.projectId}', v);
    } catch (_) {}
  }

  /// Optimistic move between columns with rollback on failure.
  Future<void> _moveTask(TaskItem task, String status) async {
    final before = _tasks;
    setState(() {
      _tasks = [
        for (final t in _tasks) t.id == task.id ? t.copyWithStatus(status) : t,
      ];
    });
    try {
      await TaskService.updateStatus(id: task.id, status: status);
    } catch (e) {
      if (!mounted) return;
      setState(() => _tasks = before);
      showSnack(context, "Couldn't move task: ${friendlyError(e)}");
    }
  }

  Future<void> _toggleArchive(Project project) async {
    try {
      await CollabService.setArchived(project.id, !project.isArchived);
      await _load(silent: true);
      if (mounted) {
        showSnack(
          context,
          project.isArchived ? 'Project restored' : 'Project archived',
        );
      }
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    }
  }

  @override
  void dispose() {
    _quickController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadViewPref();
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
      final projects = await ProjectService.list(archived: true);
      final match = projects.where((p) => p.id == widget.projectId).toList();
      if (match.isEmpty) {
        throw ApiException(404, 'Project not found or you do not have access.');
      }
      final tasks = await TaskService.list(projectId: widget.projectId);
      if (!mounted) return;
      setState(() {
        _project = match.first;
        _tasks = tasks;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteProject() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete project?'),
        content: Text(
          'This will permanently delete the project and its '
          '${_tasks.length} task${_tasks.length == 1 ? '' : 's'}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
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
          showSnack(context, 'Failed to delete project: ${friendlyError(e)}');
        }
      }
    }
  }

  /// Deletes with an Undo window instead of a blocking dialog.
  Future<void> _deleteTask(TaskItem task) async {
    setState(() => _tasks = _tasks.where((t) => t.id != task.id).toList());
    var undone = false;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final controller = messenger.showSnackBar(
      SnackBar(
        content: const Text('Task deleted'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(label: 'Undo', onPressed: () => undone = true),
      ),
    );
    await controller.closed;
    if (undone) {
      if (mounted) _load(silent: true);
      return;
    }
    try {
      await TaskService.delete(task.id);
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Failed to delete task: ${friendlyError(e)}');
        _load(silent: true);
      }
    }
  }

  List<Label> get _labelOptions {
    final seen = <int, Label>{};
    for (final t in _tasks) {
      for (final l in t.labels) {
        seen[l.id] = l;
      }
    }
    return seen.values.toList();
  }

  List<TaskItem> _byStatus(String status) {
    final q = _query.trim().toLowerCase();
    return _tasks
        .where(
          (t) =>
              t.status == status &&
              (_assigneeFilter == null || t.assignee?.id == _assigneeFilter) &&
              (_labelFilter == null ||
                  t.labels.any((l) => l.id == _labelFilter)) &&
              (q.isEmpty || t.title.toLowerCase().contains(q)),
        )
        .toList();
  }

  Future<void> _quickAdd(Project project, int? me) async {
    final title = _quickController.text.trim();
    if (_quickAdding) return;
    if (title.isEmpty) {
      _quickController.clear();
      showSnack(context, 'Enter a task title first');
      return;
    }
    final tooLong = Validators.maxLen(title, Validators.titleMax, 'Title');
    if (tooLong != null) {
      showSnack(context, tooLong);
      return;
    }
    final assignee =
        _quickAssignee ?? (project.members.any((m) => m.id == me) ? me : null);
    if (assignee == null) {
      showSnack(context, 'Choose an assignee first (person icon).');
      return;
    }
    setState(() => _quickAdding = true);
    try {
      await TaskService.create(
        title: title,
        priority: PriorityOptions.medium,
        projectId: project.id,
        assigneeId: assignee,
      );
      _quickController.clear();
      await _load(silent: true);
      if (mounted) showSnack(context, 'Task added');
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    } finally {
      if (mounted) setState(() => _quickAdding = false);
    }
  }

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
                        child: Text(
                          'This project has no members to assign to.',
                        ),
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
                              subtitle: m.designation != null
                                  ? Text(m.designation!)
                                  : null,
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () =>
                                Navigator.of(sheetContext).pop(false),
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
        showSnack(context, 'Tasks assigned');
      }
    } catch (e) {
      if (mounted) {
        showSnack(context, 'Failed to assign tasks: ${friendlyError(e)}');
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
    final sortedMembers = [...project.members]
      ..sort((a, b) => (b.isLead ? 1 : 0) - (a.isLead ? 1 : 0));

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _selectMode ? '${_selectedTaskIds.length} selected' : project.name,
        ),
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
                    icon: Icon(
                      project.isArchived
                          ? Icons.unarchive_outlined
                          : Icons.archive_outlined,
                    ),
                    tooltip: project.isArchived
                        ? 'Restore project'
                        : 'Archive project',
                    onPressed: () => _toggleArchive(project),
                  ),
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
          padding: EdgeInsets.fromLTRB(
            12 +
                (MediaQuery.sizeOf(context).width > 900
                    ? (MediaQuery.sizeOf(context).width - 860) / 2
                    : 0),
            12,
            12 +
                (MediaQuery.sizeOf(context).width > 900
                    ? (MediaQuery.sizeOf(context).width - 860) / 2
                    : 0),
            96,
          ),
          children: [
            if (project.description != null &&
                project.description!.isNotEmpty) ...[
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
                            builder: (_) =>
                                ManageMembersScreen(project: project),
                          ),
                        );
                        if (changed == true) _load();
                      },
                      icon: const Icon(
                        Icons.manage_accounts_outlined,
                        size: 18,
                      ),
                      label: const Text('Manage'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
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
              ...sortedMembers.map(
                (m) => AppCard(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 2,
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: m.avatarUrl != null && m.avatarUrl!.isNotEmpty
                        ? CircleAvatar(
                            backgroundImage: NetworkImage(m.avatarUrl!),
                          )
                        : InitialsAvatar(
                            name: m.name,
                            radius: 20,
                            avatarUrl: m.avatarUrl,
                          ),
                    title: Text(m.name),
                    subtitle: Text(m.designation ?? ''),
                    trailing: m.isLead ? const RoleBadge(label: 'LEAD') : null,
                  ),
                ),
              ),
            const SizedBox(height: 20),
            SectionHeader(title: 'Tasks', icon: Icons.task_alt_outlined),
            if (isManager && !_selectMode) ...[
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _quickController,
                      maxLength: Validators.titleMax,
                      textInputAction: TextInputAction.done,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _quickAdd(project, user?.id),
                      decoration: InputDecoration(
                        hintText: 'Quick add: type a title and press Enter',
                        isDense: true,
                        counterText: '',
                        prefixIcon: const Icon(Icons.add),
                        suffixIcon: _quickAdding
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                  PopupMenuButton<int>(
                    tooltip: 'Quick-add assignee',
                    icon: Icon(
                      Icons.person_outline,
                      color: _quickAssignee != null
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                    onSelected: (v) => setState(() => _quickAssignee = v),
                    itemBuilder: (_) => project.members
                        .map(
                          (m) => CheckedPopupMenuItem<int>(
                            value: m.id,
                            checked: _quickAssignee == m.id,
                            child: Text(m.name),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            TaskFilterBar(
              query: _query,
              status: _statusFilter,
              assigneeId: _assigneeFilter,
              assignees: project.members
                  .map((m) => MapEntry(m.id, m.name))
                  .toList(),
              onQuery: (v) => setState(() => _query = v),
              onStatus: (v) => setState(() => _statusFilter = v),
              onAssignee: (v) => setState(() => _assigneeFilter = v),
            ),
            const SizedBox(height: 12),
            if (project.isArchived)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Chip(
                  avatar: const Icon(Icons.inventory_2_outlined, size: 16),
                  label: const Text('Archived: read-only'),
                ),
              ),
            if (_labelOptions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Wrap(
                  spacing: 6,
                  children: [
                    for (final l in _labelOptions)
                      FilterChip(
                        label: Text(l.name),
                        selected: _labelFilter == l.id,
                        onSelected: (v) =>
                            setState(() => _labelFilter = v ? l.id : null),
                      ),
                  ],
                ),
              ),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.view_list_outlined),
                  label: Text('List'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.view_kanban_outlined),
                  label: Text('Board'),
                ),
              ],
              selected: {_board},
              onSelectionChanged: (v) => _setBoard(v.first),
            ),
            const SizedBox(height: 12),
            if (_board)
              SizedBox(
                height: 520,
                child: BoardView(
                  tasks: [for (final s in StatusOptions.all) ..._byStatus(s)],
                  canMove:
                      !project.isArchived &&
                      (isManager ||
                          _tasks.any((t) => t.assignee?.id == user?.id)),
                  onMove: (t, s) {
                    if (isManager || t.assignee?.id == user?.id) {
                      _moveTask(t, s);
                    } else {
                      showSnack(
                        context,
                        'Only the assignee can move this task',
                      );
                    }
                  },
                  onOpen: (t) async {
                    final changed = await openTaskDetail(context, t, project);
                    if (changed == true) await _load(silent: true);
                  },
                ),
              ),
            ...(_board
                    ? <String>[]
                    : (_statusFilter == null
                          ? StatusOptions.all
                          : [_statusFilter!]))
                .map(
                  (status) => TaskStatusColumn(
                    status: status,
                    tasks: _byStatus(status),
                    rowBuilder: (task) {
                      final canOpen =
                          isManager || task.assignee?.id == user?.id;
                      return TaskRow(
                        key: ValueKey(task.id),
                        task: task,
                        canOpen: canOpen,
                        canToggle: canOpen,
                        selectMode: _selectMode,
                        selected: _selectedTaskIds.contains(task.id),
                        onToggleDone: (done) => toggleTaskDone(
                          context,
                          task,
                          done,
                          () => _load(silent: true),
                        ),
                        onTap: () async {
                          if (_selectMode) {
                            _toggleTaskSelected(task);
                            return;
                          }
                          if (!canOpen) return;
                          final changed = await openTaskDetail(
                            context,
                            task,
                            project,
                          );
                          if (changed == true) {
                            await _load(silent: true);
                            if (context.mounted) {
                              showSnack(context, 'Task saved');
                            }
                          }
                        },
                        onLongPress: isManager
                            ? () {
                                if (!_selectMode) {
                                  setState(() => _selectMode = true);
                                }
                                _toggleTaskSelected(task);
                              }
                            : null,
                        onDelete: isManager && !_selectMode
                            ? () => _deleteTask(task)
                            : null,
                      );
                    },
                  ),
                ),
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
                if (created == true) {
                  await _load(silent: true);
                  if (context.mounted) showSnack(context, 'Task created');
                }
              },
              tooltip: 'New task',
              child: const Icon(Icons.add_task),
            )
          : null,
      bottomNavigationBar: _selectMode && _selectedTaskIds.isNotEmpty
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
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
                          : const Icon(
                              Icons.person_add_alt_1_outlined,
                              size: 18,
                            ),
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
