import 'dart:async';

import 'package:flutter/material.dart';

import '../models/collab.dart';
import '../services/collab_service.dart';
import '../utils/feedback.dart';
import '../utils/time_format.dart';
import '../widgets/loading_view.dart';
import 'project_detail_screen.dart';
import 'task_detail_screen.dart';

/// App-bar bell with an unread badge. Polls the unread count every 60s while
/// the app is in the foreground. Push (e.g. FCM) can later call [refresh]
/// through a key without changing the screen.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => NotificationBellState();
}

class NotificationBellState extends State<NotificationBell>
    with WidgetsBindingObserver {
  int _count = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
    _start();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) => refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      refresh();
      _start();
    } else {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> refresh() async {
    try {
      final c = await CollabService.unreadCount();
      if (mounted) setState(() => _count = c);
    } catch (_) {
      // Badge is best-effort; keep the last known value.
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: _count > 0 ? 'Notifications, $_count unread' : 'Notifications',
      onPressed: () async {
        await Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()));
        refresh();
      },
      icon: Badge(
        isLabelVisible: _count > 0,
        label: Text(_count > 99 ? '99+' : '$_count'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<AppNotification> _items = [];
  bool _loading = true;
  bool _more = false;
  int _page = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final p = await CollabService.notifications();
      if (!mounted) return;
      setState(() {
        _items = p.items;
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
      final p = await CollabService.notifications(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _page++;
        _more = p.hasMore;
        _items = [..._items, ...p.items];
      });
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    }
  }

  Future<void> _open(AppNotification n) async {
    try {
      if (!n.read) await CollabService.markRead(n.id);
    } catch (_) {}
    if (!mounted) return;
    if (n.taskId != null) {
      await openTaskDetail(context, taskStub(n.taskId!), null);
    } else if (n.projectId != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProjectDetailScreen(projectId: n.projectId!),
        ),
      );
    }
    if (mounted) _load(silent: true);
  }

  Future<void> _readAll() async {
    try {
      await CollabService.markAllRead();
      await _load(silent: true);
    } catch (e) {
      if (mounted) showSnack(context, friendlyError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: _items.any((n) => !n.read) ? _readAll : null,
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: _loading
          ? const LoadingView()
          : _error != null
          ? ErrorView(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: () => _load(silent: true),
              child: _items.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        Icon(
                          Icons.notifications_none,
                          size: 56,
                          color: scheme.primary,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "You're all caught up",
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : ListView.builder(
                      itemCount: _items.length + (_more ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i == _items.length) {
                          return TextButton(
                            onPressed: _loadMore,
                            child: const Text('Load more'),
                          );
                        }
                        final n = _items[i];
                        return ListTile(
                          tileColor: n.read
                              ? null
                              : scheme.primary.withValues(alpha: 0.10),
                          leading: Icon(
                            n.read
                                ? Icons.notifications_none
                                : Icons.notifications_active,
                            color: n.read ? null : scheme.primary,
                          ),
                          title: Text(
                            n.message,
                            style: TextStyle(
                              fontWeight: n.read
                                  ? FontWeight.w400
                                  : FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(relativeTime(n.createdAt)),
                          onTap: () => _open(n),
                        );
                      },
                    ),
            ),
    );
  }
}
