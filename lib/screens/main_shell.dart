import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/session.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import 'my_tasks_screen.dart';
import 'profile_screen.dart';

/// Post-login root of the app: a persistent bottom navigation bar with
/// three tabs (Dashboard, My Tasks, Profile). Tab state is preserved across
/// switches via an [IndexedStack] instead of rebuilding each tab from
/// scratch.
///
/// This widget also owns the logged-in -> logged-out transition: it watches
/// [Session] and swaps itself out for [LoginScreen] the moment the user logs
/// out from the Profile tab, mirroring the pattern `_StartupGate` in
/// main.dart uses for the initial logged-in/logged-out decision.
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const _titles = ['Dashboard', 'My Tasks', 'Profile'];

  static const _tabs = [
    HomeScreen(),
    MyTasksScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.watch<Session>().isLoggedIn;
    if (!isLoggedIn) {
      return const LoginScreen();
    }

    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: IndexedStack(
        index: _index,
        children: _tabs,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.task_alt_outlined),
            selectedIcon: Icon(Icons.task_alt),
            label: 'My Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
