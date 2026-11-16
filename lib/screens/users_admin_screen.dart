import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/layout/responsive.dart';
import '../core/widgets/app_widgets.dart';
import '../models/user.dart';
import '../services/collab_service.dart';
import '../services/session.dart';
import '../utils/feedback.dart';
import '../utils/validators.dart';
import '../widgets/loading_view.dart';
import '../widgets/status_priority_chips.dart';
import 'create_user_screen.dart';

/// Director/CEO user management: search, edit, deactivate, reset password.
class UsersAdminScreen extends StatefulWidget {
  const UsersAdminScreen({super.key});

  @override
  State<UsersAdminScreen> createState() => _UsersAdminScreenState();
}

class _UsersAdminScreenState extends State<UsersAdminScreen> {
  List<AppUser> _users = [];
  bool _loading = true;
  bool _more = false;
  int _page = 1;
  String? _error;
  String _search = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final p = await AccountService.users(search: _search);
      if (!mounted) return;
      setState(() {
        _users = p.items;
        _more = p.hasMore;
        _page = 1;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    try {
      final p = await AccountService.users(search: _search, page: _page + 1);
      if (!mounted) return;
      setState(() {
        _page++;
        _more = p.hasMore;
        _users = [..._users, ...p.items];
      });
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    }
  }

  Future<void> _run(Future<void> Function() action, String ok) async {
    try {
      await action();
      if (mounted) showSnack(context, ok);
      await _load(silent: true);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    }
  }

  Future<void> _edit(AppUser u) async {
    final name = TextEditingController(text: u.name);
    final des = TextEditingController(text: u.designation);
    var role = u.role;
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, setD) => AlertDialog(
          title: const Text('Edit user'),
          content: Form(
            key: key,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  maxLength: Validators.nameMax,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) =>
                      Validators.requiredMax(v, 'Name', Validators.nameMax),
                ),
                TextFormField(
                  controller: des,
                  maxLength: Validators.nameMax,
                  decoration: const InputDecoration(labelText: 'Designation'),
                ),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  items: const [
                    DropdownMenuItem(value: 'member', child: Text('Member')),
                    DropdownMenuItem(
                      value: 'director',
                      child: Text('Director'),
                    ),
                    DropdownMenuItem(value: 'ceo', child: Text('CEO')),
                  ],
                  onChanged: (v) => setD(() => role = v ?? role),
                  decoration: const InputDecoration(labelText: 'Role'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  key.currentState!.validate() ? Navigator.pop(d, true) : null,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    final n = name.text.trim();
    final dd = des.text.trim();
    name.dispose();
    des.dispose();
    if (ok == true) {
      await _run(
        () => AccountService.updateUser(
          u.id,
          name: n,
          designation: dd.isEmpty ? null : dd,
          role: role,
        ),
        'User updated',
      );
    }
  }

  Future<void> _toggleActive(AppUser u) async {
    if (u.isActive) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (d) => AlertDialog(
          title: Text('Deactivate ${u.name}?'),
          content: const Text(
            'They will be signed out and unable to log in until reactivated.',
          ),
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
              child: const Text('Deactivate'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    await _run(
      () => AccountService.setActive(u.id, !u.isActive),
      u.isActive ? 'User deactivated' : 'User reactivated',
    );
  }

  Future<void> _resetPassword(AppUser u) async {
    try {
      final temp = await AccountService.resetUserPassword(u.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (d) => AlertDialog(
          title: const Text('Temporary password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Share this with ${u.name}. It is shown only once.'),
              const SizedBox(height: 12),
              SelectableText(
                temp,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 18),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: temp));
                if (d.mounted) showSnack(d, 'Copied');
              },
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copy'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(d),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    }
  }

  Widget _menu(AppUser u, int? meId) => PopupMenuButton<String>(
    tooltip: 'User actions',
    onSelected: (a) {
      if (a == 'edit') _edit(u);
      if (a == 'active') _toggleActive(u);
      if (a == 'reset') _resetPassword(u);
    },
    itemBuilder: (_) => [
      const PopupMenuItem(value: 'edit', child: Text('Edit')),
      if (u.id != meId)
        PopupMenuItem(
          value: 'active',
          child: Text(u.isActive ? 'Deactivate' : 'Reactivate'),
        ),
      const PopupMenuItem(value: 'reset', child: Text('Reset password')),
    ],
  );

  /// Wide-screen layout: sortable-looking table with all columns visible.
  Widget _table(int? meId, ColorScheme scheme) => ListView(
    padding: EdgeInsets.fromLTRB(
      context.pagePadding,
      0,
      context.pagePadding,
      96,
    ),
    children: [
      Card(
        child: SizedBox(
          width: double.infinity,
          child: DataTable(
            headingTextStyle: Theme.of(context).textTheme.labelLarge,
            columns: const [
              DataColumn(label: Text('User')),
              DataColumn(label: Text('Email')),
              DataColumn(label: Text('Designation')),
              DataColumn(label: Text('Role')),
              DataColumn(label: Text('Status')),
              DataColumn(label: Text('')),
            ],
            rows: [
              for (final u in _users)
                DataRow(
                  cells: [
                    DataCell(
                      Row(
                        children: [
                          UserAvatar(
                            name: u.name,
                            imageUrl: u.avatarUrl,
                            size: 32,
                          ),
                          const SizedBox(width: Space.sm),
                          Text(u.name),
                        ],
                      ),
                    ),
                    DataCell(Text(u.email)),
                    DataCell(Text(u.designation ?? '-')),
                    DataCell(Text(u.role.toUpperCase())),
                    DataCell(
                      Text(
                        u.isActive ? 'Active' : 'Disabled',
                        style: TextStyle(
                          color: u.isActive ? null : scheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    DataCell(_menu(u, meId)),
                  ],
                ),
            ],
          ),
        ),
      ),
      if (_more)
        TextButton(onPressed: _loadMore, child: const Text('Load more')),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final me = context.read<Session>().currentUser;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Users')),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Create user',
        onPressed: () async {
          await Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const CreateUserScreen()));
          _load(silent: true);
        },
        child: const Icon(Icons.person_add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search name or email',
              ),
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () {
                  _search = v.trim();
                  _load(silent: true);
                });
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const LoadingView()
                : _error != null
                ? ErrorView(message: _error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: () => _load(silent: true),
                    child: _users.isEmpty
                        ? ListView(
                            children: const [
                              SizedBox(height: 80),
                              Center(child: Text('No users found')),
                            ],
                          )
                        : context.isWide
                        ? _table(me?.id, scheme)
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 96),
                            itemCount: _users.length + (_more ? 1 : 0),
                            itemBuilder: (context, i) {
                              if (i == _users.length)
                                return TextButton(
                                  onPressed: _loadMore,
                                  child: const Text('Load more'),
                                );
                              final u = _users[i];
                              return ListTile(
                                leading: InitialsAvatar(
                                  name: u.name,
                                  radius: 20,
                                  avatarUrl: u.avatarUrl,
                                ),
                                title: Text(u.name),
                                subtitle: Text(
                                  '${u.email}\n${u.role.toUpperCase()}${u.designation != null ? ' · ${u.designation}' : ''}',
                                ),
                                isThreeLine: true,
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Chip(
                                      label: Text(
                                        u.isActive ? 'Active' : 'Disabled',
                                      ),
                                      avatar: Icon(
                                        u.isActive
                                            ? Icons.check_circle_outline
                                            : Icons.block,
                                        size: 16,
                                        color: u.isActive ? null : scheme.error,
                                      ),
                                    ),
                                    _menu(u, me?.id),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
