import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/project.dart';
import '../services/project_service.dart';
import '../services/session.dart';
import '../services/api_client.dart';
import '../widgets/loading_view.dart';
import 'login_screen.dart';
import 'profile_screen.dart';
import 'project_detail_screen.dart';
import 'project_edit_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Project>> _future;

  @override
  void initState() {
    super.initState();
    _future = ProjectService.list();
  }

  void _reload() {
    setState(() {
      _future = ProjectService.list();
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<Session>();
    final user = session.currentUser;
    final canManage = user?.isDirectorOrCeo ?? false;

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
        child: FutureBuilder<List<Project>>(
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
            final projects = snapshot.data ?? [];
            if (projects.isEmpty) {
              return const Center(child: Text('No projects yet.'));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: projects.length,
              itemBuilder: (context, index) {
                final project = projects[index];
                final leadNames = project.leads.map((m) => m.name).join(', ');
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    title: Text(project.name),
                    subtitle: Text(
                      '${project.members.length} member(s)'
                      '${leadNames.isNotEmpty ? ' · Lead: $leadNames' : ''}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProjectDetailScreen(projectId: project.id),
                        ),
                      );
                      _reload();
                    },
                  ),
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
