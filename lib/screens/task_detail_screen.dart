import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/theme/brand_colors.dart';
import '../models/collab.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../services/collab_service.dart';
import '../services/project_service.dart';
import '../services/session.dart';
import '../services/task_service.dart';
import '../utils/feedback.dart';
import '../utils/time_format.dart';
import '../widgets/app_card.dart';
import '../widgets/comment_composer.dart';
import '../widgets/loading_view.dart';
import '../widgets/status_priority_chips.dart';
import 'task_edit_screen.dart';

/// Opens the detail screen; resolves to true when something changed.
Future<bool?> openTaskDetail(
  BuildContext context,
  TaskItem task,
  Project? project,
) {
  return Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => TaskDetailScreen(taskId: task.id, project: project),
    ),
  );
}

Color labelColor(String name) =>
    AppColors.labelPalette[name] ?? AppColors.labelFallback;

class LabelChip extends StatelessWidget {
  final Label label;
  const LabelChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = labelColor(label.color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.6)),
      ),
      child: Text(label.name, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class TaskDetailScreen extends StatefulWidget {
  final int taskId;
  final Project? project;
  const TaskDetailScreen({super.key, required this.taskId, this.project});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  TaskItem? _task;
  Project? _project;
  List<Comment> _comments = []; // oldest first
  bool _moreComments = false;
  int _commentPage = 1;
  List<ActivityItem> _activity = [];
  bool _loading = true;
  String? _error;
  bool _changed = false;
  final _subtaskController = TextEditingController();
  int _tempId = 0;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _load();
  }

  @override
  void dispose() {
    _subtaskController.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        CollabService.task(widget.taskId),
        CollabService.comments(widget.taskId),
        CollabService.taskActivity(widget.taskId),
      ]);
      final task = results[0] as TaskItem;
      Project? project = _project;
      if (project == null || project.members.isEmpty) {
        final all = await ProjectService.list();
        final m = all.where((p) => p.id == task.projectId).toList();
        if (m.isNotEmpty) project = m.first;
      }
      final comments = results[1] as PagedList<Comment>;
      if (!mounted) return;
      setState(() {
        _task = task;
        _project = project;
        _comments = comments.items.reversed.toList();
        _moreComments = comments.hasMore;
        _commentPage = 1;
        _activity = (results[2] as PagedList<ActivityItem>).items;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadEarlier() async {
    try {
      final page = await CollabService.comments(
        widget.taskId,
        page: _commentPage + 1,
      );
      if (!mounted) return;
      setState(() {
        _commentPage++;
        _moreComments = page.hasMore;
        _comments = [...page.items.reversed, ..._comments];
      });
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    }
  }

  bool get _isManager =>
      context.read<Session>().currentUser?.isDirectorOrCeo ?? false;

  bool get _isLead {
    final me = context.read<Session>().currentUser?.id;
    return _project?.members.any((m) => m.id == me && m.isLead) ?? false;
  }

  bool get _isAssignee =>
      _task?.assignee?.id == context.read<Session>().currentUser?.id;

  bool get _readOnly => _project?.isArchived ?? false;

  Future<void> _setStatus(String status) async {
    final task = _task!;
    if (status == task.status) return;
    try {
      await TaskService.updateStatus(id: task.id, status: status);
      _changed = true;
      await _load(silent: true);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    }
  }

  Future<void> _edit() async {
    final project = _project;
    if (project == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => TaskEditScreen(project: project, task: _task),
      ),
    );
    if (changed == true) {
      _changed = true;
      await _load(silent: true);
      if (mounted) showSnack(context, 'Task saved');
    }
  }

  Future<void> _sendComment(String body) async {
    final me = context.read<Session>().currentUser!;
    final tempId = --_tempId;
    final pending = Comment(
      id: tempId,
      body: body,
      author: null,
      createdAt: DateTime.now(),
      pending: true,
    );
    setState(() => _comments = [..._comments, pending]);
    await _submit(tempId, body, me.name);
  }

  Future<void> _submit(int tempId, String body, String meName) async {
    try {
      final saved = await CollabService.addComment(widget.taskId, body);
      if (!mounted) return;
      setState(
        () =>
            _comments = [for (final c in _comments) c.id == tempId ? saved : c],
      );
      final act = await CollabService.taskActivity(widget.taskId);
      if (mounted) setState(() => _activity = act.items);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _comments = [
          for (final c in _comments)
            c.id == tempId ? c.copyWith(pending: false, failed: true) : c,
        ],
      );
      showSnack(context, friendlyError(e));
    }
  }

  Future<void> _retry(Comment c) async {
    setState(
      () => _comments = [
        for (final x in _comments)
          x.id == c.id ? x.copyWith(pending: true, failed: false) : x,
      ],
    );
    await _submit(c.id, c.body, '');
  }

  Future<void> _deleteComment(Comment c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Delete comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(d).colorScheme.error,
              foregroundColor: Theme.of(d).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await CollabService.deleteComment(c.id);
      if (mounted)
        setState(
          () => _comments = _comments.where((x) => x.id != c.id).toList(),
        );
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    }
  }

  Future<void> _editLabels() async {
    final task = _task!;
    var available = await CollabService.labels(task.projectId);
    final selected = task.labels.map((l) => l.id).toSet();
    final nameCtl = TextEditingController();
    var newColor = 'blue';
    const palette = [
      'red',
      'orange',
      'amber',
      'green',
      'teal',
      'blue',
      'purple',
      'pink',
      'gray',
    ];
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setD) => AlertDialog(
          title: const Text('Labels'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (available.isEmpty)
                    const Text('No labels yet. Create one below.'),
                  for (final l in available)
                    CheckboxListTile(
                      dense: true,
                      value: selected.contains(l.id),
                      title: LabelChip(label: l),
                      onChanged: (v) => setD(
                        () => v == true
                            ? selected.add(l.id)
                            : selected.remove(l.id),
                      ),
                    ),
                  const Divider(),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final c in palette)
                        Semantics(
                          label: 'Colour $c',
                          button: true,
                          selected: newColor == c,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => setD(() => newColor = c),
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: labelColor(c),
                              child: newColor == c
                                  ? const Icon(
                                      Icons.check,
                                      size: 14,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ),
                        ),
                    ],
                  ),
                  TextField(
                    controller: nameCtl,
                    maxLength: 30,
                    decoration: InputDecoration(
                      labelText: 'New label',
                      suffixIcon: IconButton(
                        tooltip: 'Create label',
                        icon: const Icon(Icons.add),
                        onPressed: () async {
                          final n = nameCtl.text.trim();
                          if (n.isEmpty) return;
                          try {
                            final l = await CollabService.addLabel(
                              task.projectId,
                              n,
                              newColor,
                            );
                            setD(() {
                              available = [...available, l];
                              selected.add(l.id);
                              nameCtl.clear();
                            });
                          } catch (e) {
                            if (context.mounted)
                              showSnack(context, friendlyError(e));
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    nameCtl.dispose();
    if (ok != true) return;
    try {
      await CollabService.setTaskLabels(task.id, selected.toList());
      _changed = true;
      await _load(silent: true);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    }
  }

  Future<void> _addSubtask() async {
    final title = _subtaskController.text.trim();
    if (title.isEmpty) {
      showSnack(context, 'Enter a subtask title first');
      _subtaskController.clear();
      return;
    }
    try {
      await CollabService.addSubtask(widget.taskId, title);
      _subtaskController.clear();
      _changed = true;
      await _load(silent: true);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    }
  }

  Future<void> _toggleSubtask(Subtask s, bool done) async {
    try {
      await CollabService.setSubtaskDone(widget.taskId, s.id, done);
      _changed = true;
      await _load(silent: true);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    }
  }

  Future<void> _reorderSubtasks(
    TaskItem task,
    int oldIndex,
    int newIndex,
  ) async {
    final list = [...task.subtasks];
    if (newIndex > oldIndex) newIndex--;
    list.insert(newIndex, list.removeAt(oldIndex));
    try {
      for (final (i, s) in list.indexed) {
        await CollabService.moveSubtask(task.id, s.id, i);
      }
      _changed = true;
      await _load(silent: true);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    }
  }

  Future<void> _deleteSubtask(Subtask s) async {
    try {
      await CollabService.deleteSubtask(widget.taskId, s.id);
      _changed = true;
      await _load(silent: true);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = _task;
    final canEdit = _isManager && !_readOnly;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Task'),
          actions: [
            if (canEdit && task != null)
              IconButton(
                tooltip: 'Edit task',
                icon: const Icon(Icons.edit_outlined),
                onPressed: _edit,
              ),
          ],
        ),
        body: _loading
            ? const LoadingView()
            : _error != null || task == null
            ? ErrorView(message: _error ?? 'Task not found', onRetry: _load)
            : Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => _load(silent: true),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              _header(task),
                              const SizedBox(height: 16),
                              _subtasks(task),
                              const SizedBox(height: 16),
                              _commentsSection(),
                              const SizedBox(height: 16),
                              _activitySection(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!_readOnly) CommentComposer(onSend: _sendComment),
                ],
              ),
      ),
    );
  }

  Widget _header(TaskItem task) {
    final theme = Theme.of(context);
    final fmt = DateFormat('MMM d, y');
    final canStatus = (_isManager || _isAssignee) && !_readOnly;
    final canLabel = (_isManager || _isLead) && !_readOnly;
    Widget row(IconData i, String t) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(i, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(t, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(task.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              StatusChip(status: task.status),
              PriorityChip(priority: task.priority),
              if (task.isOverdue) const OverdueChip(),
            ],
          ),
          const SizedBox(height: 12),
          if (canStatus)
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                for (final s in StatusOptions.all)
                  ButtonSegment(
                    value: s,
                    label: Text(
                      StatusOptions.label(s),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              selected: {task.status},
              onSelectionChanged: (v) => _setStatus(v.first),
            ),
          if (task.assignee != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  InitialsAvatar(
                    name: task.assignee!.name,
                    radius: 12,
                    avatarUrl: task.assignee!.avatarUrl,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(task.assignee!.name)),
                ],
              ),
            ),
          if (task.due != null)
            row(
              Icons.event_outlined,
              'Due ${fmt.format(task.due!)}${task.isOverdue ? ' (overdue)' : ''}',
            ),
          if (task.startDate != null)
            row(
              Icons.play_arrow_outlined,
              'Starts ${fmt.format(DateTime.parse(task.startDate!))}',
            ),
          if (task.estimateHours != null)
            row(Icons.timer_outlined, 'Estimate ${task.estimateHours} h'),
          if (task.projectName != null)
            row(Icons.folder_outlined, task.projectName!),
          if (task.creatorName != null)
            row(
              Icons.person_outline,
              'Created by ${task.creatorName}${task.createdAt != null ? ' · ${relativeTime(DateTime.parse(task.createdAt!).toLocal())}' : ''}',
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final l in task.labels) LabelChip(label: l),
              if (canLabel)
                ActionChip(
                  avatar: const Icon(Icons.label_outline, size: 16),
                  label: const Text('Labels'),
                  onPressed: _editLabels,
                ),
            ],
          ),
          if ((task.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(task.description!, style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }

  Widget _subtasks(TaskItem task) {
    final canManage = (_isManager || _isLead) && !_readOnly;
    final canTick = (canManage || _isAssignee) && !_readOnly;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Checklist',
            icon: Icons.checklist,
            trailing: Text('${task.subtasksDoneCount}/${task.subtasks.length}'),
          ),
          if (task.subtasks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('No subtasks yet.'),
            ),
          ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorder: canManage
                ? (o, n) => _reorderSubtasks(task, o, n)
                : (_, _) {},
            children: [
              for (final (i, s) in task.subtasks.indexed)
                KeyedSubtree(
                  key: ValueKey(s.id),
                  child: CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: s.isDone,
                    onChanged: canTick
                        ? (v) => _toggleSubtask(s, v ?? false)
                        : null,
                    title: Text(
                      s.title,
                      style: TextStyle(
                        decoration: s.isDone
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    secondary: canManage
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Delete subtask',
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () => _deleteSubtask(s),
                              ),
                              ReorderableDragStartListener(
                                index: i,
                                child: const Tooltip(
                                  message: 'Drag to reorder',
                                  child: Icon(Icons.drag_handle),
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                ),
            ],
          ),
          if (canManage)
            TextField(
              controller: _subtaskController,
              maxLength: 255,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addSubtask(),
              decoration: InputDecoration(
                hintText: 'Add a subtask',
                counterText: '',
                suffixIcon: IconButton(
                  tooltip: 'Add subtask',
                  icon: const Icon(Icons.add),
                  onPressed: _addSubtask,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _commentsSection() {
    final me = context.read<Session>().currentUser;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Comments',
            icon: Icons.chat_bubble_outline,
          ),
          if (_moreComments)
            TextButton(
              onPressed: _loadEarlier,
              child: const Text('Load earlier comments'),
            ),
          if (_comments.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('No comments yet. Start the conversation.'),
            ),
          for (final c in _comments)
            Builder(
              builder: (context) {
                final authorName = c.author?.name ?? me?.name ?? 'You';
                final mine = c.author?.id == me?.id || c.id < 0;
                final canDelete =
                    !c.pending &&
                    !c.failed &&
                    (mine || _isManager || _isLead) &&
                    !_readOnly;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: InitialsAvatar(
                    name: authorName,
                    radius: 16,
                    avatarUrl:
                        c.author?.avatarUrl ??
                        (c.id < 0 ? me?.avatarUrl : null),
                  ),
                  title: Text(
                    '$authorName · ${c.pending ? 'sending…' : relativeTime(c.createdAt)}',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.body),
                      if (c.failed)
                        TextButton.icon(
                          onPressed: () => _retry(c),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Failed to send. Retry'),
                        ),
                    ],
                  ),
                  trailing: canDelete
                      ? IconButton(
                          tooltip: 'Delete comment',
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () => _deleteComment(c),
                        )
                      : null,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _activitySection() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Activity', icon: Icons.history),
          if (_activity.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('No activity yet.'),
            ),
          for (final a in _activity)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.circle, size: 8),
              title: Text(a.message),
              subtitle: Text(relativeTime(a.createdAt)),
            ),
        ],
      ),
    );
  }
}

/// Minimal task reference for navigation by id only.
TaskItem taskStub(int id) => TaskItem(
  id: id,
  title: '',
  status: 'todo',
  priority: 'medium',
  projectId: 0,
);
