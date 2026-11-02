import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../services/project_service.dart';
import '../services/task_service.dart';
import '../services/session.dart';
import '../services/api_client.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/loading_view.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'project_detail_screen.dart';
import 'project_edit_screen.dart';

class _HomeData {
  final List<Project> projects;
  final int overdueCount;

  _HomeData({required this.projects, required this.overdueCount});
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<_HomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HomeData> _load() async {
    final projects = await ProjectService.list();
    var overdueCount = 0;
    try {
      final tasks = await TaskService.list();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      overdueCount = tasks.where((t) {
        if (t.status == StatusOptions.done) return false;
        if (t.dueDate == null) return false;
        final due = DateTime.tryParse(t.dueDate!);
        if (due == null) return false;
        return due.isBefore(today);
      }).length;
    } catch (_) {
      // Overdue count is a nice-to-have on the dashboard header; if the
      // tasks endpoint fails for any reason, don't block the project list.
      overdueCount = 0;
    }
    return _HomeData(projects: projects, overdueCount: overdueCount);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final user = session.currentUser;
    final canManage = user?.isDirectorOrCeo ?? false;
    final firstName = (user?.name.isNotEmpty ?? false)
        ? user!.name.trim().split(RegExp(r'\s+')).first
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('TaskNest'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profile',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              );
              if (!mounted) return;
              // ignore: use_build_context_synchronously
              final stillLoggedIn = context.read<Session>().isLoggedIn;
              if (stillLoggedIn) return;
              if (!mounted) return;
              // ignore: use_build_context_synchronously
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _reload();
          await _future;
        },
        child: FutureBuilder<_HomeData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LoadingView();
            }
            if (snapshot.hasError) {
              return ErrorView(
                message: 'Failed to load projects.\n${snapshot.error}\n\nBase URL: ${ApiClient.baseUrl}',
                onRetry: _reload,
              );
            }
            final data = snapshot.data!;
            final projects = data.projects;

            return LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 760;
                final crossAxisCount = isWide ? 2 : 1;

                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _DashboardHeader(
                        firstName: firstName,
                        projects: projects,
                        overdueCount: data.overdueCount,
                      ),
                    ),
                    if (projects.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: Text('No projects yet.')),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        sliver: SliverGrid(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: 14,
                            crossAxisSpacing: 14,
                            mainAxisExtent: 148,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final project = projects[index];
                              return _ProjectStatCard(
                                project: project,
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ProjectDetailScreen(projectId: project.id),
                                    ),
                                  );
                                  _reload();
                                },
                              );
                            },
                            childCount: projects.length,
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton(
              onPressed: () async {
                final created = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const ProjectEditScreen()),
                );
                if (created == true) _reload();
              },
              tooltip: 'New project',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

/// Navy header band with a greeting and an aggregate quick-stats strip,
/// giving the home screen a sense of place instead of dropping straight
/// into a bare list.
class _DashboardHeader extends StatelessWidget {
  final String? firstName;
  final List<Project> projects;
  final int overdueCount;

  const _DashboardHeader({
    required this.firstName,
    required this.projects,
    required this.overdueCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final totalTasks = projects.fold<int>(0, (sum, p) => sum + p.tasksCount);

    final headerBg = isDark
        ? const Color(0xFF0F1F3D)
        : const Color(0xFF1B2A4A);
    const headerFg = Color(0xFFFAF6EE);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: headerBg,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            firstName != null ? 'Welcome back, $firstName' : 'Welcome back',
            style: const TextStyle(
              color: headerFg,
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            "Here's what's happening across your projects.",
            style: TextStyle(
              color: headerFg.withValues(alpha: 0.75),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _QuickStat(
                  icon: Icons.folder_outlined,
                  label: 'Projects',
                  value: '${projects.length}',
                  fg: headerFg,
                ),
              ),
              _StatDivider(color: headerFg),
              Expanded(
                child: _QuickStat(
                  icon: Icons.task_alt_outlined,
                  label: 'Tasks',
                  value: '$totalTasks',
                  fg: headerFg,
                ),
              ),
              _StatDivider(color: headerFg),
              Expanded(
                child: _QuickStat(
                  icon: Icons.warning_amber_rounded,
                  label: 'Overdue',
                  value: '$overdueCount',
                  fg: overdueCount > 0 ? const Color(0xFFE38671) : headerFg,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  final Color color;
  const _StatDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      color: color.withValues(alpha: 0.2),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color fg;

  const _QuickStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: fg.withValues(alpha: 0.85)),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                color: fg,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: fg.withValues(alpha: 0.7),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// Full-width "stat card" replacing the old plain ListTile: project name,
/// a progress bar for task completion, member avatars, and a completion
/// count, per the client-approved reference shape.
class _ProjectStatCard extends StatelessWidget {
  final Project project;
  final VoidCallback onTap;

  const _ProjectStatCard({required this.project, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final progress = project.progress.clamp(0.0, 1.0);
    final progressPercent = (progress * 100).round();
    final memberNames = project.members.map((m) => m.name).toList();

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.folder_outlined, size: 18, color: colorScheme.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      project.name,
                      style: theme.textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(Icons.chevron_right, color: colorScheme.outline),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: project.tasksCount == 0 ? 0 : progress,
                        minHeight: 8,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    project.tasksCount == 0 ? '--' : '$progressPercent%',
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (memberNames.isNotEmpty) AvatarStack(names: memberNames, size: 22),
                  if (memberNames.isNotEmpty) const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      memberNames.isEmpty
                          ? 'No members yet'
                          : '${memberNames.length} member${memberNames.length == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.check_circle_outline, size: 15, color: colorScheme.secondary),
                  const SizedBox(width: 4),
                  Text(
                    '${project.tasksDoneCount}/${project.tasksCount} done',
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
