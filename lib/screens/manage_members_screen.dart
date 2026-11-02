import 'package:flutter/material.dart';
import '../models/project.dart';
import '../models/task_assignee.dart';
import '../services/project_service.dart';
import '../services/user_service.dart';
import '../widgets/app_card.dart';
import '../widgets/loading_view.dart';
import 'create_user_screen.dart';

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
    var candidates = _allUsers.where((u) => !memberIds.contains(u.id)).toList();

    if (candidates.isEmpty) {
      final created = await _promptCreateUser();
      if (created == null) return;
      await _loadUsers();
      memberIds.clear();
      memberIds.addAll(_project.members.map((m) => m.id));
      candidates = _allUsers.where((u) => !memberIds.contains(u.id)).toList();
      if (candidates.isEmpty) return;
    }
    if (!mounted) return;

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
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () async {
                        Navigator.of(dialogContext).pop(false);
                        final created = await _promptCreateUser();
                        if (created != null) {
                          await _loadUsers();
                          if (mounted) _addMember();
                        }
                      },
                      icon: const Icon(Icons.person_add_alt_outlined, size: 18),
                      label: const Text("Can't find them? Create a new user"),
                    ),
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

  /// Pushes the Create User screen and returns the newly created user, or
  /// null if the user backed out without creating one.
  Future<TaskAssignee?> _promptCreateUser() {
    return Navigator.of(context).push<TaskAssignee>(
      MaterialPageRoute(builder: (_) => const CreateUserScreen()),
    );
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
                : _project.members.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.group_outlined,
                                  size: 40,
                                  color: Theme.of(context).colorScheme.outline),
                              const SizedBox(height: 12),
                              const Text('No members yet.'),
                              const SizedBox(height: 4),
                              Text(
                                'Tap the + button below to add one.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _project.members.length,
                        itemBuilder: (context, index) {
                          final member = _project.members[index];
                          final colorScheme = Theme.of(context).colorScheme;
                          return AppCard(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(member.name,
                                  style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(member.designation ?? ''),
                              leading: CircleAvatar(
                                backgroundColor: member.isLead
                                    ? colorScheme.primary
                                    : colorScheme.secondary,
                                foregroundColor: colorScheme.onPrimary,
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
                                    icon: Icon(Icons.delete_outline, color: colorScheme.error),
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
