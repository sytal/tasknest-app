import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../services/project_service.dart';
import '../services/session.dart';
import '../services/task_service.dart';
import '../utils/feedback.dart';
import '../widgets/loading_view.dart';
import '../widgets/task_row.dart';
import 'task_detail_screen.dart';

/// All overdue (past due, not done) tasks the user can see.
class OverdueScreen extends StatefulWidget {
  const OverdueScreen({super.key});

  @override
  State<OverdueScreen> createState() => _OverdueScreenState();
}

class _OverdueScreenState extends State<OverdueScreen> {
  List<TaskItem> _tasks = [];
  List<Project> _projects = [];
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
      final r = await Future.wait([TaskService.list(), ProjectService.list()]);
      if (!mounted) return;
      setState(() {
        _tasks = (r[0] as List<TaskItem>).where((t) => t.isOverdue).toList()
          ..sort((a, b) => a.due!.compareTo(b.due!));
        _projects = r[1] as List<Project>;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<Session>().currentUser;
    final isManager = user?.isDirectorOrCeo ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Overdue tasks')),
      body: _loading
          ? const LoadingView()
          : _error != null
          ? ErrorView(message: _error!, onRetry: _load)
          : _tasks.isEmpty
          ? const Center(child: Text('Nothing is overdue. Nice work!'))
          : RefreshIndicator(
              onRefresh: _load,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                    children: _tasks.map((task) {
                      final canOpen =
                          isManager || task.assignee?.id == user?.id;
                      return TaskRow(
                        task: task,
                        canOpen: canOpen,
                        canToggle: canOpen,
                        onToggleDone: (done) =>
                            toggleTaskDone(context, task, done, _load),
                        onTap: () async {
                          final project = _projects.firstWhere(
                            (p) => p.id == task.projectId,
                            orElse: () => Project(
                              id: task.projectId,
                              name: task.projectName ?? 'Project',
                              members: const [],
                            ),
                          );
                          final changed = await openTaskDetail(
                            context,
                            task,
                            project,
                          );
                          if (changed == true) _load();
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
    );
  }
}
