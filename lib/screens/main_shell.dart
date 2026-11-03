import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navTint = isDark ? AppColors.navy900 : AppColors.navy700;

    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: Text(_titles[_index])),
      body: IndexedStack(
        index: _index,
        children: _tabs,
      ),
      // Frosted-glass bottom nav bar: a blurred backdrop behind a
      // translucent navy tint, rather than a flat opaque fill, so content
      // scrolling underneath softly shows through.
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              backgroundColor: navTint.withValues(alpha: 0.72),
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              indicatorColor: Colors.white.withValues(alpha: 0.16),
              iconTheme: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return IconThemeData(
                  color: AppColors.cream50.withValues(alpha: selected ? 1 : 0.65),
                );
              }),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                final selected = states.contains(WidgetState.selected);
                return TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: AppColors.cream50.withValues(alpha: selected ? 1 : 0.65),
                );
              }),
            ),
            child: NavigationBar(
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
          ),
        ),
      ),
    );
  }
}
