import 'package:flutter/material.dart';

import '../models/project.dart';
import '../services/api_client.dart';
import '../models/task_assignee.dart';
import '../services/project_service.dart';
import '../services/user_service.dart';
import '../utils/validators.dart';
import '../widgets/unsaved_guard.dart';

/// Create or edit a project. Pass [project] to edit, omit to create.
class ProjectEditScreen extends StatefulWidget {
  final Project? project;

  const ProjectEditScreen({super.key, this.project});

  @override
  State<ProjectEditScreen> createState() => _ProjectEditScreenState();
}

class _ProjectEditScreenState extends State<ProjectEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  bool _saving = false;
  bool _dirty = false;
  String? _error;
  Map<String, String> _fieldErrors = {};
  List<TaskAssignee> _users = [];
  final Map<int, String> _picked = {}; // userId -> project role

  Future<void> _loadUsers() async {
    try {
      final u = await UserService.list();
      if (mounted) setState(() => _users = u);
    } catch (_) {
      // Optional picker: members can still be added later from Manage.
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.project == null) _loadUsers();
    _nameController = TextEditingController(text: widget.project?.name ?? '');
    _descController = TextEditingController(
      text: widget.project?.description ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  bool get _isEditing => widget.project != null;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = {};
    });
    try {
      Project? created;
      if (_isEditing) {
        await ProjectService.update(
          id: widget.project!.id,
          name: _nameController.text.trim(),
          description: _descController.text.trim(),
        );
      } else {
        created = await ProjectService.create(
          name: _nameController.text.trim(),
          description: _descController.text.trim(),
          members: [
            for (final e in _picked.entries) {'user_id': e.key, 'project_role': e.value},
          ],
        );
      }
      if (mounted) {
        _dirty = false;
        Navigator.of(context).pop(created ?? true);
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
    return UnsavedChangesGuard(
      dirty: _dirty && !_saving,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit Project' : 'New Project'),
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      autofocus: !_isEditing,
                      maxLength: Validators.nameMax,
                      textInputAction: TextInputAction.next,
                      textCapitalization: TextCapitalization.words,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      decoration: const InputDecoration(
                        labelText: 'Project name',
                      ),
                      validator: (v) =>
                          Validators.requiredMax(
                            v,
                            'Name',
                            Validators.nameMax,
                          ) ??
                          _fieldErrors['name'],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descController,
                      maxLines: 4,
                      maxLength: Validators.projectDescriptionMax,
                      textCapitalization: TextCapitalization.sentences,
                      validator: (v) => Validators.maxLen(
                        v,
                        Validators.projectDescriptionMax,
                        'Description',
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Description (optional)',
                      ),
                    ),
                    if (!_isEditing && _users.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text('Members (optional)', style: Theme.of(context).textTheme.titleSmall),
                      for (final u in _users)
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          value: _picked.containsKey(u.id),
                          title: Text(u.name),
                          secondary: _picked.containsKey(u.id)
                              ? SegmentedButton<String>(
                                  showSelectedIcon: false,
                                  segments: const [
                                    ButtonSegment(value: 'member', label: Text('Member')),
                                    ButtonSegment(value: 'lead', label: Text('Lead')),
                                  ],
                                  selected: {_picked[u.id]!},
                                  onSelectionChanged: (v) => setState(() => _picked[u.id] = v.first),
                                )
                              : null,
                          onChanged: (v) => setState(() {
                            _dirty = true;
                            v == true ? _picked[u.id] = 'member' : _picked.remove(u.id);
                          }),
                        ),
                    ],
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
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _isEditing ? 'Save Changes' : 'Create Project',
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
