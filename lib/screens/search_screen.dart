import 'dart:async';

import 'package:flutter/material.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../services/collab_service.dart';
import '../utils/feedback.dart';
import '../widgets/status_priority_chips.dart';
import 'project_detail_screen.dart';
import 'task_detail_screen.dart';

/// Global search (projects, tasks, people for director/CEO), debounced 300ms, min 2 chars.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  Timer? _debounce;
  bool _loading = false;
  String? _error;
  String _last = '';
  List<Project> _projects = [];
  List<TaskItem> _tasks = [];
  List<AppUser> _users = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    final q = v.trim();
    if (q.length < 2) {
      setState(() {
        _projects = [];
        _tasks = [];
        _users = [];
        _error = null;
        _last = '';
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () => _run(q));
  }

  Future<void> _run(String q) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await CollabService.search(q);
      if (!mounted || _controller.text.trim() != q) return;
      setState(() {
        _last = q;
        _projects = (r['projects'] as List)
            .map((e) => Project.fromJson(e as Map<String, dynamic>))
            .toList();
        _tasks = (r['tasks'] as List)
            .map((e) => TaskItem.fromJson(e as Map<String, dynamic>))
            .toList();
        _users = (r['users'] as List)
            .map((e) => AppUser.fromJson(e as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _group(String title, List<Widget> children) => children.isEmpty
      ? const SizedBox.shrink()
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(title, style: Theme.of(context).textTheme.titleSmall),
            ),
            ...children,
          ],
        );

  @override
  Widget build(BuildContext context) {
    final empty =
        _last.isNotEmpty &&
        !_loading &&
        _projects.isEmpty &&
        _tasks.isEmpty &&
        _users.isEmpty;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search projects, tasks, people',
            border: InputBorder.none,
            filled: false,
          ),
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear search',
              icon: const Icon(Icons.close),
              onPressed: () {
                _controller.clear();
                _onChanged('');
              },
            ),
        ],
      ),
      body: ListView(
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(_error!)),
          if (_last.isEmpty && !_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Type at least 2 characters to search.'),
            ),
          if (empty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No results found.'),
            ),
          _group('Projects', [
            for (final p in _projects)
              ListTile(
                leading: const Icon(Icons.folder_outlined),
                title: Text(p.name),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProjectDetailScreen(projectId: p.id),
                  ),
                ),
              ),
          ]),
          _group('Tasks', [
            for (final t in _tasks)
              ListTile(
                leading: const Icon(Icons.task_alt),
                title: Text(t.title),
                subtitle: Text(t.projectName ?? ''),
                trailing: StatusChip(status: t.status),
                onTap: () => openTaskDetail(context, t, null),
              ),
          ]),
          _group('People', [
            for (final u in _users)
              ListTile(
                leading: InitialsAvatar(
                  name: u.name,
                  radius: 16,
                  avatarUrl: u.avatarUrl,
                ),
                title: Text(u.name),
                subtitle: Text('${u.email} · ${u.role}'),
              ),
          ]),
        ],
      ),
    );
  }
}
