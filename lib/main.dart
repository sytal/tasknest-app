import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:provider/provider.dart';

import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'services/session.dart';
import 'theme/app_theme.dart';
import 'widgets/loading_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Expose the semantics tree on web so screen readers and UI tests can see widgets.
  if (kIsWeb) SemanticsBinding.instance.ensureSemantics();
  runApp(
    ChangeNotifierProvider(create: (_) => Session(), child: const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskNest',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.system,
      home: const _StartupGate(),
    );
  }
}

/// Decides whether to show the login screen or the home screen, based on
/// whether a stored auth token still resolves to a valid user.
class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  late Future<bool> _restoreFuture;

  @override
  void initState() {
    super.initState();
    _restoreFuture = context.read<Session>().tryRestore();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _restoreFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(body: LoadingView());
        }
        final loggedIn = snapshot.data ?? false;
        return loggedIn ? const MainShell() : const LoginScreen();
      },
    );
  }
}
