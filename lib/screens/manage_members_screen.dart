import 'package:flutter/material.dart';
import '../models/project.dart';
import '../models/task_assignee.dart';
import '../services/project_service.dart';
import '../services/user_service.dart';
import '../widgets/loading_view.dart';

class ManageMembersScreen extends StatefulWidget {
  final Project project;

  const ManageMembersScreen({super.key, required this.project});

  @override
  State<ManageMembersScreen> createState() => _ManageMembersScreenState();
}

class _ManageMembersScreenState extends State<ManageMembersScreen> {
  late Project _project;
  List<TaskAssignee> _allUsers = [];
  bool _loadingUsers = true;
  String? _error;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
    try {
      _allUsers = await UserService.list();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loadingUsers = false);
    }
  }

  Future<void> _reloadProject() async {
    final projects = await ProjectService.list();
    final updated = projects.where((p) => p.id == _project.id).toList();
    if (updated.isNotEmpty) {
      setState(() => _project = updated.first);
    }
  }

  Future<void> _addMember() async {
    final memberIds = _project.members.map((m) => m.id).toSet();
    final candidates = _allUsers.where((u) => !memberIds.contains(u.id)).toList();
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All users are already members.')),
      );
      return;
    }

    TaskAssignee? selectedUser = candidates.first;
    String role = 'member';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Add Member'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<TaskAssignee>(
                    initialValue: selectedUser,
                    items: candidates
                        .map((u) => DropdownMenuItem(value: u, child: Text(u.name)))
                        .toList(),
                    onChanged: (v) => setDialogState(() => selectedUser = v),
                    decoration: const InputDecoration(labelText: 'User'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    items: const [
                      DropdownMenuItem(value: 'member', child: Text('Member')),
                      DropdownMenuItem(value: 'lead', child: Text('Lead')),
                    ],
                    onChanged: (v) => setDialogState(() => role = v ?? 'member'),
                    decoration: const InputDecoration(labelText: 'Project role'),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && selectedUser != null) {
      try {
        await ProjectService.addMember(
          projectId: _project.id,
          userId: selectedUser!.id,
          projectRole: role,
        );
        _changed = true;
        await _reloadProject();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Failed to add member: $e')));
        }
      }
    }
  }

  Future<void> _changeRole(int userId, String currentRole) async {
    final newRole = currentRole == 'lead' ? 'member' : 'lead';
    try {
      await ProjectService.updateMemberRole(
        projectId: _project.id,
        userId: userId,
        projectRole: newRole,
      );
      _changed = true;
      await _reloadProject();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to update role: $e')));
      }
    }
  }

  Future<void> _removeMember(int userId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove member?'),
        content: const Text('This will remove them from the project.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ProjectService.removeMember(projectId: _project.id, userId: userId);
      _changed = true;
      await _reloadProject();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to remove member: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(title: Text('Manage: ${_project.name}')),
        body: _loadingUsers
            ? const LoadingView()
            : _error != null
                ? ErrorView(message: _error!, onRetry: _loadUsers)
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _project.members.length,
                    itemBuilder: (context, index) {
                      final member = _project.members[index];
                      return Card(
                        child: ListTile(
                          title: Text(member.name),
                          subtitle: Text(member.designation ?? ''),
                          leading: CircleAvatar(
                            child: Text(member.isLead ? 'L' : 'M'),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton(
                                onPressed: () =>
                                    _changeRole(member.id, member.projectRole),
                                child: Text(member.isLead ? 'Make Member' : 'Make Lead'),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Colors.red),
                                onPressed: () => _removeMember(member.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
        floatingActionButton: FloatingActionButton(
          onPressed: _addMember,
          tooltip: 'Add member',
          child: const Icon(Icons.person_add),
        ),
      ),
    );
  }
}
