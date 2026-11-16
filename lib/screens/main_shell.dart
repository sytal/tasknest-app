import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/layout/responsive.dart';
import '../core/widgets/brand_logo.dart';
import '../services/session.dart';
import '../theme/app_theme.dart';
import 'calendar_screen.dart';
import 'home_screen.dart';
import 'notifications_screen.dart';
import 'search_screen.dart';
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

  static const _tabs = [HomeScreen(), MyTasksScreen(), ProfileScreen()];

  List<Widget> _actions(BuildContext context) => [
    if (_index == 0) ...[
      IconButton(
        tooltip: 'Search',
        icon: const Icon(Icons.search),
        onPressed: () =>
            Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const SearchScreen())),
      ),
      const NotificationBell(),
    ],
    if (_index == 1)
      IconButton(
        tooltip: 'Calendar',
        icon: const Icon(Icons.calendar_month_outlined),
        onPressed: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const CalendarScreen())),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.watch<Session>().isLoggedIn;
    if (!isLoggedIn) {
      return const LoginScreen();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sc = context.sizeClass;
    if (sc != SizeClass.compact) {
      final extended = sc == SizeClass.expanded || sc == SizeClass.large;
      return Scaffold(
        appBar: AppBar(
          title: Text(_titles[_index]),
          actions: _actions(context),
        ),
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              extended: extended,
              minExtendedWidth: 200,
              labelType: extended
                  ? NavigationRailLabelType.none
                  : NavigationRailLabelType.all,
              indicatorColor: Theme.of(context).colorScheme.secondary
                  .withValues(alpha: 0.25),
              leading: Padding(
                padding: const EdgeInsets.symmetric(vertical: Space.lg),
                child: extended
                    ? const BrandWordmark(markSize: 36)
                    : const BrandLogo(width: 40, markOnly: true),
              ),
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.space_dashboard_outlined),
                  selectedIcon: Icon(Icons.space_dashboard),
                  label: Text('Dashboard'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.task_alt_outlined),
                  selectedIcon: Icon(Icons.task_alt),
                  label: Text('My Tasks'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.person_outline),
                  selectedIcon: Icon(Icons.person),
                  label: Text('Profile'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: BrandBackground(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1400),
                    child: IndexedStack(index: _index, children: _tabs),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: Text(_titles[_index]), actions: _actions(context)),
      body: BrandBackground(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: IndexedStack(index: _index, children: _tabs),
          ),
        ),
      ),
      // Frosted-glass bottom nav bar: a blurred backdrop behind a
      // translucent navy tint, rather than a flat opaque fill, so content
      // scrolling underneath softly shows through.
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surface,
          elevation: 3,
          surfaceTintColor: Colors.transparent,
          indicatorColor: isDark
              ? AppColors.orangeDark
              : Theme.of(context).colorScheme.secondary.withValues(alpha: 0.30),
          iconTheme: WidgetStateProperty.resolveWith((st) {
            final sel = st.contains(WidgetState.selected);
            return IconThemeData(
              color: sel
                  ? (isDark
                        ? AppColors.navyDark
                        : Theme.of(context).colorScheme.onSurface)
                  : Theme.of(context).colorScheme.onSurface
                        .withValues(alpha: 0.7),
            );
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((st) {
            final sel = st.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 12,
              fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
              color: Theme.of(context).colorScheme.onSurface
                  .withValues(alpha: sel ? 1 : 0.75),
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
    );
  }
}
