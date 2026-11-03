import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../services/session.dart';
import '../services/user_service.dart';
import '../widgets/app_card.dart';
import 'create_user_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _updatingAvatar = false;

  Future<void> _showAvatarOptions() async {
    final session = context.read<Session>();
    final hasAvatar = (session.currentUser?.avatarUrl ?? '').isNotEmpty;

    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from gallery'),
                onTap: () => Navigator.of(sheetContext).pop('gallery'),
              ),
              // image_picker's camera source isn't supported on Flutter web,
              // so hide this option there rather than offering something
              // that would fail silently.
              if (!kIsWeb)
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Take photo'),
                  onTap: () => Navigator.of(sheetContext).pop('camera'),
                ),
              if (hasAvatar)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Remove photo'),
                  onTap: () => Navigator.of(sheetContext).pop('remove'),
                ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('Cancel'),
                onTap: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          ),
        );
      },
    );

    if (choice == null) return;

    if (choice == 'remove') {
      await _removeAvatar();
      return;
    }

    final source = choice == 'camera' ? ImageSource.camera : ImageSource.gallery;
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 85);
    if (picked == null) return;
    await _uploadAvatar(picked);
  }

  Future<void> _uploadAvatar(XFile picked) async {
    setState(() => _updatingAvatar = true);
    try {
      final bytes = await picked.readAsBytes();
      final updated = await UserService.uploadAvatar(
        bytes: bytes,
        filename: picked.name.isNotEmpty ? picked.name : 'avatar.jpg',
      );
      if (mounted) context.read<Session>().updateUser(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to update photo: $e')));
      }
    } finally {
      if (mounted) setState(() => _updatingAvatar = false);
    }
  }

  Future<void> _removeAvatar() async {
    final session = context.read<Session>();
    final current = session.currentUser;
    if (current == null) return;
    setState(() => _updatingAvatar = true);
    try {
      await UserService.deleteAvatar();
      session.updateUser(current.copyWith(clearAvatarUrl: true));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to remove photo: $e')));
      }
    } finally {
      if (mounted) setState(() => _updatingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<Session>().currentUser;
    final colorScheme = Theme.of(context).colorScheme;
    final canManageUsers = user?.isDirectorOrCeo ?? false;
    final hasAvatar = (user?.avatarUrl ?? '').isNotEmpty;

    // No AppBar here: this screen is hosted as the "Profile" tab inside
    // MainShell, which supplies the shared AppBar and bottom navigation.
    // Logging out just clears the Session; MainShell watches Session and
    // swaps the whole shell out for LoginScreen automatically, so this
    // widget doesn't need to navigate itself.
    return Scaffold(
      body: user == null
          ? const Center(child: Text('Not logged in'))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Center(
                  child: Column(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundColor: colorScheme.primary,
                            backgroundImage: hasAvatar
                                ? NetworkImage(user.avatarUrl!)
                                : null,
                            child: hasAvatar
                                ? null
                                : Text(
                                    user.name.isNotEmpty
                                        ? user.name[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w700,
                                      color: colorScheme.onPrimary,
                                    ),
                                  ),
                          ),
                          Positioned(
                            right: -2,
                            bottom: -2,
                            child: InkWell(
                              onTap: _updatingAvatar ? null : _showAvatarOptions,
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: colorScheme.secondary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: colorScheme.surface, width: 2),
                                ),
                                child: _updatingAvatar
                                    ? SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: colorScheme.onSecondary,
                                        ),
                                      )
                                    : Icon(
                                        Icons.camera_alt_outlined,
                                        size: 14,
                                        color: colorScheme.onSecondary,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _updatingAvatar ? null : _showAvatarOptions,
                        child: Text(hasAvatar ? 'Change photo' : 'Add photo'),
                      ),
                      const SizedBox(height: 8),
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
