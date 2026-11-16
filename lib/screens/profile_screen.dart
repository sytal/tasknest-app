import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/layout/responsive.dart';
import '../core/theme/brand_colors.dart';
import '../services/api_client.dart';
import '../services/session.dart';
import '../services/theme_controller.dart';
import '../utils/feedback.dart';
import '../services/user_service.dart';
import '../widgets/app_card.dart';
import 'account_screens.dart';
import 'create_user_screen.dart';
import 'users_admin_screen.dart';

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

    final source = choice == 'camera'
        ? ImageSource.camera
        : ImageSource.gallery;
    final picked = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked == null) return;
    await _uploadAvatar(picked);
  }

  Future<void> _uploadAvatar(XFile picked) async {
    setState(() => _updatingAvatar = true);
    try {
      final bytes = await picked.readAsBytes();
      final ext = picked.name.split('.').last.toLowerCase();
      if (!['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
        throw ApiException(422, 'Please choose a JPG or PNG image.');
      }
      if (bytes.length > 2 * 1024 * 1024) {
        throw ApiException(422, 'Image must be smaller than 2 MB.');
      }
      final updated = await UserService.uploadAvatar(
        bytes: bytes,
        filename: picked.name.isNotEmpty ? picked.name : 'avatar.jpg',
      );
      if (mounted) context.read<Session>().updateUser(updated);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(_avatarError(e))));
      }
    } finally {
      if (mounted) setState(() => _updatingAvatar = false);
    }
  }

  /// Turns upload failures (including Laravel validation text) into friendly copy.
  String _avatarError(Object e) {
    if (e is ApiException) {
      final m = e.message.toLowerCase();
      if (m.contains('kilobytes') ||
          m.contains('greater than') ||
          m.contains('too large')) {
        return 'Image must be smaller than 2 MB.';
      }
      if (e.statusCode == 422) {
        return m.contains('2 mb')
            ? e.message
            : 'Please choose a JPG or PNG image.';
      }
      return e.message;
    }
    return friendlyError(e);
  }

  Future<void> _removeAvatar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Remove profile photo?'),
        content: const Text('Your initials will be shown instead.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(d, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(d).colorScheme.error,
              foregroundColor: Theme.of(d).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
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
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
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
      backgroundColor: Colors.transparent,
      body: user == null
          ? const Center(child: Text('Not logged in'))
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    bottomNavClearance(context) + 20,
                  ),
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 24,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.navy, AppColors.navy600],
                        ),
                      ),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 40,
                                backgroundColor: AppColors.orange,
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
                                          color: AppColors.navyDeep,
                                        ),
                                      ),
                              ),
                              Positioned(
                                right: -2,
                                bottom: -2,
                                child: Tooltip(
                                  message: 'Change profile photo',
                                  child: InkWell(
                                    onTap: _updatingAvatar
                                        ? null
                                        : _showAvatarOptions,
                                    borderRadius: BorderRadius.circular(16),
                                    child: Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: colorScheme.secondary,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: colorScheme.surface,
                                          width: 2,
                                        ),
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
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _updatingAvatar
                                ? null
                                : _showAvatarOptions,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.amber,
                            ),
                            child: Text(
                              hasAvatar ? 'Change photo' : 'Add photo',
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            user.name,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            user.email,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    AppCard(
                      child: Column(
                        children: [
                          _InfoRow(
                            label: 'Designation',
                            value: user.designation ?? '-',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          ListTile(
                            leading: const Icon(Icons.edit_outlined),
                            title: const Text('Edit profile'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const EditProfileScreen(),
                              ),
                            ),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.lock_outline),
                            title: const Text('Change password'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ChangePasswordScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Appearance',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final o in const [
                                (
                                  ThemeMode.system,
                                  'System',
                                  Icons.brightness_auto_outlined,
                                ),
                                (
                                  ThemeMode.light,
                                  'Light',
                                  Icons.light_mode_outlined,
                                ),
                                (
                                  ThemeMode.dark,
                                  'Dark',
                                  Icons.dark_mode_outlined,
                                ),
                              ])
                                ChoiceChip(
                                  avatar: Icon(o.$3, size: 18),
                                  label: Text(o.$2),
                                  selected:
                                      context.watch<ThemeController>().mode ==
                                      o.$1,
                                  onSelected: (_) =>
                                      context.read<ThemeController>().set(o.$1),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (canManageUsers) ...[
                      const SizedBox(height: 20),
                      SectionHeader(
                        title: 'Administration',
                        icon: Icons.admin_panel_settings_outlined,
                      ),
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          leading: Icon(
                            Icons.person_add_alt_outlined,
                            color: colorScheme.primary,
                          ),
                          title: const Text('Create User'),
                          subtitle: const Text(
                            'Add a new director, CEO, or member account',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const CreateUserScreen(),
                              ),
                            );
                          },
                        ),
                      ),
                      AppCard(
                        padding: EdgeInsets.zero,
                        child: ListTile(
                          leading: Icon(
                            Icons.groups_outlined,
                            color: colorScheme.primary,
                          ),
                          title: const Text('Manage users'),
                          subtitle: const Text(
                            'Search, edit, deactivate, reset password',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const UsersAdminScreen(),
                            ),
                          ),
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
              ),
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
