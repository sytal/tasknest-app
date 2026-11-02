import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/session.dart';
import '../widgets/app_card.dart';
import 'create_user_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<Session>().currentUser;
    final colorScheme = Theme.of(context).colorScheme;
    final canManageUsers = user?.isDirectorOrCeo ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: user == null
          ? const Center(child: Text('Not logged in'))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: colorScheme.primary,
                        child: Text(
                          user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        user.name,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                AppCard(
                  child: Column(
                    children: [
                      _InfoRow(label: 'Role', value: user.role.toUpperCase()),
                      const Divider(height: 1),
                      _InfoRow(label: 'Designation', value: user.designation ?? '-'),
                    ],
                  ),
                ),
                if (canManageUsers) ...[
                  const SizedBox(height: 20),
                  SectionHeader(title: 'Administration', icon: Icons.admin_panel_settings_outlined),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: ListTile(
                      leading: Icon(Icons.person_add_alt_outlined, color: colorScheme.primary),
                      title: const Text('Create User'),
                      subtitle: const Text('Add a new director, CEO, or member account'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const CreateUserScreen()),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: () async {
                    await context.read<Session>().logout();
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  icon: const Icon(Icons.logout),
                  label: const Text('Log Out'),
                ),
              ],
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text(value),
        ],
      ),
    );
  }
}
