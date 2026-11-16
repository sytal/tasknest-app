import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../services/api_client.dart';
import '../services/session.dart';
import '../utils/validators.dart';
import '../services/task_service.dart';

/// Create/edit a task, or (for members) update only the status of their own task.
///
/// Pass [task] to edit an existing task, or omit it to create a new one
/// (requires [project] for the member picker).
class TaskEditScreen extends StatefulWidget {
  final Project project;
  final TaskItem? task;

  const TaskEditScreen({super.key, required this.project, this.task});

  @override
  State<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends State<TaskEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late String _priority;
  late String _status;
  DateTime? _dueDate;
  int? _assigneeId;
  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = {};
  bool _dirty = false;

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task?.title ?? '');
    _titleController.addListener(_markDirty);
    _descController = TextEditingController(text: task?.description ?? '');
    _priority = task?.priority ?? PriorityOptions.medium;
    _status = task?.status ?? StatusOptions.todo;
    _dueDate = task?.dueDate != null ? DateTime.tryParse(task!.dueDate!) : null;
    final me = context.read<Session>().currentUser?.id;
    _assigneeId =
        task?.assignee?.id ??
        (widget.project.members.any((m) => m.id == me) ? me : null);
  }

  void _markDirty() {
    if (!_dirty) _dirty = true;
  }

  Future<bool> _confirmDiscard() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('Your unsaved changes will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  bool _canEditFields(bool isManager) {
    // Director/CEO can always edit full fields. Members can only change status
    // on an existing task assigned to them (handled by the caller gating access).
    return isManager;
  }

  Future<void> _pickDueDate(bool canEdit) async {
    if (!canEdit) return;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime(now.year, now.month, now.day),
      // New tasks can't start in the past; existing overdue dates stay valid.
      firstDate: (_dueDate != null && _dueDate!.isBefore(now))
          ? _dueDate!
          : DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        _dueDate = picked;
        _dirty = true;
      });
    }
  }

  Future<void> _submit(bool isManager) async {
    if (isManager && !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = {};
    });
    try {
      if (isManager) {
        final dueDateStr = _dueDate != null
            ? DateFormat('yyyy-MM-dd').format(_dueDate!)
            : null;
        if (_isEditing) {
          await TaskService.update(
            id: widget.task!.id,
            title: _titleController.text.trim(),
            description: _descController.text.trim(),
            priority: _priority,
            dueDate: dueDateStr,
            assigneeId: _assigneeId!,
            status: _status,
          );
        } else {
          await TaskService.create(
            title: _titleController.text.trim(),
            description: _descController.text.trim(),
            priority: _priority,
            dueDate: dueDateStr,
            projectId: widget.project.id,
            assigneeId: _assigneeId!,
          );
        }
      } else {
        // Member: only status can change.
        await TaskService.updateStatus(id: widget.task!.id, status: _status);
      }
      if (mounted) {
        _dirty = false;
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      setState(() {
        _fieldErrors = e.fieldErrors;
        _error = e.fieldErrors.isEmpty ? e.message : null;
      });
      _formKey.currentState?.validate();
    } catch (_) {
      setState(() => _error = 'Could not reach the server. Try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<Session>().currentUser;
    final isManager = user?.isDirectorOrCeo ?? false;
    final fieldsEditable = _canEditFields(isManager);
    final dateFormat = DateFormat('MMM d, yyyy');

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmDiscard()) {
          setState(() => _dirty = false);
          nav.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isEditing ? (fieldsEditable ? 'Edit Task' : 'Task') : 'New Task',
          ),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    TextFormField(
                      controller: _titleController,
                      enabled: fieldsEditable,
                      autofocus: !_isEditing,
                      maxLength: Validators.titleMax,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.sentences,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: const InputDecoration(labelText: 'Title'),
                      validator: (v) =>
                          Validators.requiredMax(
                            v,
                            'Title',
                            Validators.titleMax,
                          ) ??
                          _fieldErrors['title'],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descController,
                      enabled: fieldsEditable,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: Validators.descriptionMax,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => _markDirty(),
                      validator: (v) => Validators.maxLen(
                        v,
                        Validators.descriptionMax,
                        'Description',
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _priority,
                      isExpanded: true,
                      items: PriorityOptions.all
                          .map(
                            (p) => DropdownMenuItem(
                              value: p,
                              child: Text(
                                PriorityOptions.label(p),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: fieldsEditable
                          ? (v) => setState(() {
                              _priority = v ?? _priority;
                              _dirty = true;
                            })
                          : null,
                      decoration: const InputDecoration(labelText: 'Priority'),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () => _pickDueDate(fieldsEditable),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Due date',
                        ),
                        child: Text(
                          _dueDate != null
                              ? dateFormat.format(_dueDate!)
                              : 'No due date',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<int>(
                      initialValue: _assigneeId,
                      isExpanded: true,
                      items: widget.project.members
                          .map(
                            (m) => DropdownMenuItem(
                              value: m.id,
                              child: Text(
                                m.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: fieldsEditable
                          ? (v) => setState(() {
                              _assigneeId = v;
                              _dirty = true;
                            })
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'Assignee',
                        hintText: 'Select who is responsible',
                      ),
                      validator: (v) => fieldsEditable && v == null
                          ? 'Please select an assignee'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      isExpanded: true,
                      items: StatusOptions.all
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(
                                StatusOptions.label(s),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() {
                        _status = v ?? _status;
                        _dirty = true;
                      }),
                      decoration: const InputDecoration(labelText: 'Status'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : () => _submit(isManager),
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              isManager
                                  ? (_isEditing
                                        ? 'Save Changes'
                                        : 'Create Task')
                                  : 'Update Status',
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
