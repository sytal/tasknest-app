import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../services/session.dart';
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

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    _titleController = TextEditingController(text: task?.title ?? '');
    _descController = TextEditingController(text: task?.description ?? '');
    _priority = task?.priority ?? PriorityOptions.medium;
    _status = task?.status ?? StatusOptions.todo;
    _dueDate = task?.dueDate != null ? DateTime.tryParse(task!.dueDate!) : null;
    _assigneeId = task?.assignee?.id ??
        (widget.project.members.isNotEmpty ? widget.project.members.first.id : null);
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
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  Future<void> _submit(bool isManager) async {
    if (isManager && !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (isManager) {
        final dueDateStr =
            _dueDate != null ? DateFormat('yyyy-MM-dd').format(_dueDate!) : null;
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
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = e.toString());
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

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? (fieldsEditable ? 'Edit Task' : 'Task') : 'New Task'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _titleController,
                enabled: fieldsEditable,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                enabled: fieldsEditable,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _priority,
                items: PriorityOptions.all
                    .map((p) => DropdownMenuItem(value: p, child: Text(PriorityOptions.label(p))))
                    .toList(),
                onChanged: fieldsEditable ? (v) => setState(() => _priority = v ?? _priority) : null,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => _pickDueDate(fieldsEditable),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Due date',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _dueDate != null ? dateFormat.format(_dueDate!) : 'No due date',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: _assigneeId,
                items: widget.project.members
                    .map((m) => DropdownMenuItem(value: m.id, child: Text(m.name)))
                    .toList(),
                onChanged: fieldsEditable ? (v) => setState(() => _assigneeId = v) : null,
                decoration: const InputDecoration(
                  labelText: 'Assignee',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _status,
                items: StatusOptions.all
                    .map((s) => DropdownMenuItem(value: s, child: Text(StatusOptions.label(s))))
                    .toList(),
                onChanged: (v) => setState(() => _status = v ?? _status),
                decoration: const InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.red)),
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
                    : Text(isManager
                        ? (_isEditing ? 'Save Changes' : 'Create Task')
                        : 'Update Status'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
