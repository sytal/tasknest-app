import 'package:flutter/material.dart';

import '../widgets/dashboard_sections.dart';
import 'package:provider/provider.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../services/project_service.dart';
import '../services/task_service.dart';
import '../services/session.dart';
import '../widgets/initials_avatar.dart';
import '../widgets/loading_view.dart';
import '../widgets/glass_surface.dart';
import 'project_detail_screen.dart';
import 'overdue_screen.dart';
import 'project_edit_screen.dart';
import '../utils/feedback.dart';

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
  bool _archived = false;
  int _sectionsKey = 0;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_HomeData> _load() async {
    final projects = await ProjectService.list(archived: _archived);
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
      _sectionsKey++;
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

    // No AppBar here: this screen is hosted as the "Dashboard" tab inside
    // MainShell, which supplies the shared AppBar and bottom navigation.
    return Scaffold(
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
                message:
                    'Failed to load projects.\n${friendlyError(snapshot.error!)}',
                onRetry: _reload,
              );
            }
            final data = snapshot.data!;
            final projects = data.projects;

            return LayoutBuilder(
              builder: (context, constraints) {
                return CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _DashboardHeader(
                        firstName: firstName,
                        role: user?.role,
                        designation: user?.designation,
                        projects: projects,
                        overdueCount: data.overdueCount,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: DashboardSections(
                        key: ValueKey(_sectionsKey),
                        showWorkload: canManage,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FilterChip(
                            avatar: const Icon(Icons.inventory_2_outlined, size: 16),
                            label: const Text('Show archived'),
                            selected: _archived,
                            onSelected: (v) {
                              _archived = v;
                              _reload();
                            },
                          ),
                        ),
                      ),
                    ),
                    if (projects.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: Text('No projects yet.')),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 520,
                                mainAxisSpacing: 14,
                                crossAxisSpacing: 14,
                                mainAxisExtent: 156,
                              ),
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            final project = projects[index];
                            return FadeSlideIn(
                              delay: Duration(
                                milliseconds: 40 * index.clamp(0, 8),
                              ),
                              child: _ProjectStatCard(
                                project: project,
                                onTap: () async {
                                  await Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ProjectDetailScreen(
                                        projectId: project.id,
                                      ),
                                    ),
                                  );
                                  _reload();
                                },
                              ),
                            );
                          }, childCount: projects.length),
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
          ? Padding(
              // MainShell's frosted bottom nav overlaps this tab's body
              // (extendBody), so lift the FAB above it on narrow layouts.
              padding: EdgeInsets.only(
                bottom: MediaQuery.sizeOf(context).width >= 840
                    ? 0
                    : kBottomNavigationBarHeight +
                          MediaQuery.paddingOf(context).bottom +
                          8,
              ),
              child: FloatingActionButton(
                onPressed: () async {
                  final created = await Navigator.of(context).push<Object>(
                    MaterialPageRoute(
                      builder: (_) => const ProjectEditScreen(),
                    ),
                  );
                  if (created == null) return;
                  _reload();
                  if (created is Project && context.mounted) {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProjectDetailScreen(projectId: created.id),
                      ),
                    );
                    _reload();
                  }
                },
                tooltip: 'New project',
                child: const Icon(Icons.add),
              ),
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
  final String? role;
  final String? designation;
  final List<Project> projects;
  final int overdueCount;

  const _DashboardHeader({
    required this.firstName,
    required this.role,
    required this.designation,
    required this.projects,
    required this.overdueCount,
  });

  /// Maps the raw role string to a human-friendly label, e.g.
  /// "Director", "CEO", or "Member — Senior Developer" when a designation
  /// is present for a plain member.
  String _roleLabel() {
    final r = role?.trim();
    if (r == null || r.isEmpty) return '';
    final roleTitle = switch (r.toLowerCase()) {
      'ceo' => 'CEO',
      'director' => 'Director',
      _ => 'Member',
    };
    final d = designation?.trim();
    if (roleTitle == 'Member' && d != null && d.isNotEmpty) {
      return 'Member — $d';
    }
    return roleTitle;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final totalTasks = projects.fold<int>(0, (sum, p) => sum + p.tasksCount);

    final headerBg = isDark ? const Color(0xFF0F1F3D) : const Color(0xFF1B2A4A);
    const headerFg = Color(0xFFFAF6EE);
    final roleLabel = _roleLabel();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: headerBg,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B152B).withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  firstName != null
                      ? 'Welcome back, $firstName'
                      : 'Welcome back',
                  style: const TextStyle(
                    color: headerFg,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (roleLabel.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: headerFg.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    roleLabel,
                    style: TextStyle(
                      color: headerFg.withValues(alpha: 0.95),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
            ],
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
          GlassSurface(
            tintColor: Colors.white,
            tintOpacity: 0.08,
            blurSigma: 14,
            borderRadius: BorderRadius.circular(18),
            padding: const EdgeInsets.all(10),
            border: Border.all(color: headerFg.withValues(alpha: 0.14)),
            child: Row(
              children: [
                Expanded(
                  child: _QuickStatCard(
                    icon: Icons.folder_outlined,
                    label: 'Projects',
                    value: '${projects.length}',
                    fg: headerFg,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickStatCard(
                    icon: Icons.task_alt_outlined,
                    label: 'Tasks',
                    value: '$totalTasks',
                    fg: headerFg,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickStatCard(
                    icon: Icons.warning_amber_rounded,
                    label: 'Overdue',
                    value: '$overdueCount',
                    fg: overdueCount > 0 ? const Color(0xFFE38671) : headerFg,
                    highlighted: overdueCount > 0,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const OverdueScreen()),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual stat tile rendered as its own card within the navy header,
/// instead of a plain text column separated by a thin divider line.
class _QuickStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color fg;
  final bool highlighted;
  final VoidCallback? onTap;

  const _QuickStatCard({
    this.onTap,
    required this.icon,
    required this.label,
    required this.value,
    required this.fg,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: highlighted ? 0.10 : 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: fg.withValues(alpha: highlighted ? 0.35 : 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: highlighted ? 0.18 : 0.12),
            ),
            child: Icon(icon, size: 18, color: fg.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: fg,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: fg.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return card;
    return Semantics(
      button: true,
      label: '$label: $value. Tap to view.',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: card,
      ),
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

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Card(
        child: InkWell(
          onTap: onTap,
          splashColor: colorScheme.primary.withValues(alpha: 0.08),
          highlightColor: colorScheme.primary.withValues(alpha: 0.04),
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
                      child: Icon(
                        Icons.folder_outlined,
                        size: 18,
                        color: colorScheme.primary,
                      ),
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
                          valueColor: AlwaysStoppedAnimation(
                            colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      project.tasksCount == 0 ? '--' : '$progressPercent%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (memberNames.isNotEmpty)
                      AvatarStack(names: memberNames, size: 22),
                    if (memberNames.isNotEmpty) const SizedBox(width: 8),
                    if (project.isArchived)
                      const Padding(
                        padding: EdgeInsets.only(right: 6),
                        child: Icon(Icons.inventory_2_outlined, size: 16),
                      ),
                    if (project.overdueCount > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          '${project.overdueCount} overdue',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.error,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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
                    Icon(
                      Icons.check_circle_outline,
                      size: 15,
                      color: colorScheme.secondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${project.tasksDoneCount}/${project.tasksCount} done',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
