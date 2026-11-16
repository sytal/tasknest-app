import '../models/collab.dart';
import '../models/project.dart';
import '../models/task.dart';
import '../models/task_assignee.dart';
import '../models/user.dart';
import 'api_client.dart';

class PagedList<T> {
  final List<T> items;
  final bool hasMore;
  PagedList(this.items, this.hasMore);
}

PagedList<T> _page<T>(
  Map<String, dynamic> body,
  T Function(Map<String, dynamic>) f,
) {
  final items = ((body['data'] as List?) ?? [])
      .map((e) => f(e as Map<String, dynamic>))
      .toList();
  final meta = body['meta'] as Map<String, dynamic>?;
  final hasMore =
      meta != null &&
      (meta['current_page'] as int) < (meta['last_page'] as int);
  return PagedList(items, hasMore);
}

/// Comments, activity, notifications, subtasks, labels, dashboard, search.
class CollabService {
  static Future<PagedList<Comment>> comments(
    int taskId, {
    int page = 1,
  }) async => _page(
    await ApiClient.getPage('/tasks/$taskId/comments?page=$page'),
    Comment.fromJson,
  );

  static Future<Comment> addComment(int taskId, String body) async =>
      Comment.fromJson(
        await ApiClient.post('/tasks/$taskId/comments', {'body': body})
            as Map<String, dynamic>,
      );

  static Future<void> deleteComment(int id) =>
      ApiClient.delete('/comments/$id');

  static Future<PagedList<ActivityItem>> taskActivity(
    int taskId, {
    int page = 1,
  }) async => _page(
    await ApiClient.getPage('/tasks/$taskId/activity?page=$page'),
    ActivityItem.fromJson,
  );

  static Future<PagedList<ActivityItem>> projectActivity(
    int projectId, {
    int page = 1,
  }) async => _page(
    await ApiClient.getPage('/projects/$projectId/activity?page=$page'),
    ActivityItem.fromJson,
  );

  static Future<TaskItem> task(int id) async => TaskItem.fromJson(
    await ApiClient.get('/tasks/$id') as Map<String, dynamic>,
  );

  // Notifications
  static Future<PagedList<AppNotification>> notifications({
    int page = 1,
  }) async => _page(
    await ApiClient.getPage('/notifications?page=$page'),
    AppNotification.fromJson,
  );

  static Future<int> unreadCount() async {
    final r = await ApiClient.get(
      '/notifications/unread-count',
    ) as Map<String, dynamic>;
    return r['count'] as int;
  }

  static Future<void> markRead(String id) =>
      ApiClient.post('/notifications/$id/read', {});

  static Future<void> markAllRead() =>
      ApiClient.post('/notifications/read-all', {});

  // Subtasks
  static Future<Subtask> addSubtask(int taskId, String title) async =>
      Subtask.fromJson(
        await ApiClient.post('/tasks/$taskId/subtasks', {'title': title})
            as Map<String, dynamic>,
      );

  static Future<void> setSubtaskDone(int taskId, int id, bool done) =>
      ApiClient.put('/tasks/$taskId/subtasks/$id', {'is_done': done});

  static Future<void> moveSubtask(int taskId, int id, int position) =>
      ApiClient.put('/tasks/$taskId/subtasks/$id', {'position': position});

  static Future<void> deleteSubtask(int taskId, int id) =>
      ApiClient.delete('/tasks/$taskId/subtasks/$id');

  // Labels
  static Future<List<Label>> labels(int projectId) async =>
      ((await ApiClient.get('/projects/$projectId/labels')) as List)
          .map((e) => Label.fromJson(e as Map<String, dynamic>))
          .toList();

  static Future<Label> addLabel(
    int projectId,
    String name,
    String color,
  ) async => Label.fromJson(
    await ApiClient.post('/projects/$projectId/labels', {
      'name': name,
      'color': color,
    }) as Map<String, dynamic>,
  );

  static Future<void> deleteLabel(int projectId, int id) =>
      ApiClient.delete('/projects/$projectId/labels/$id');

  static Future<void> setTaskLabels(int taskId, List<int> ids) =>
      ApiClient.put('/tasks/$taskId', {'label_ids': ids});

  // Projects
  static Future<void> setArchived(int projectId, bool archived) =>
      ApiClient.post(
        '/projects/$projectId/${archived ? 'archive' : 'unarchive'}',
        {},
      );

  static Future<List<Project>> projects({bool archived = false}) async =>
      ((await ApiClient.get('/projects?archived=${archived ? 1 : 0}')) as List)
          .map((e) => Project.fromJson(e as Map<String, dynamic>))
          .toList();

  // Dashboard + search
  static Future<Map<String, dynamic>> dashboard() async =>
      (await ApiClient.get('/dashboard')) as Map<String, dynamic>;

  static Future<Map<String, dynamic>> search(String q) async =>
      (await ApiClient.get('/search?q=${Uri.encodeQueryComponent(q)}'))
          as Map<String, dynamic>;

  static Future<List<TaskItem>> tasksDue(DateTime from, DateTime to) async {
    String d(DateTime t) => t.toIso8601String().substring(0, 10);
    final data = await ApiClient.get(
      '/tasks?mine=1&due_from=${d(from)}&due_to=${d(to)}',
    );
    return (data as List)
        .map((e) => TaskItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}

/// Profile, password and user administration.
class AccountService {
  static Future<AppUser> updateProfile(String name, String? designation) async {
    final r = await ApiClient.put('/me', {
      'name': name,
      'designation': designation,
    }) as Map<String, dynamic>;
    return AppUser.fromJson(r['user'] as Map<String, dynamic>);
  }

  static Future<void> changePassword(
    String current,
    String next,
    String confirm,
  ) => ApiClient.put('/me/password', {
    'current_password': current,
    'password': next,
    'password_confirmation': confirm,
  });

  static Future<void> forgotPassword(String email) =>
      ApiClient.post('/forgot-password', {'email': email});

  static Future<void> resetPassword(
    String email,
    String token,
    String password,
    String confirm,
  ) => ApiClient.post('/reset-password', {
    'email': email,
    'token': token,
    'password': password,
    'password_confirmation': confirm,
  });

  static Future<PagedList<AppUser>> users({
    String search = '',
    String? role,
    int page = 1,
  }) async {
    final q =
        'page=$page&search=${Uri.encodeQueryComponent(search)}${role != null ? '&role=$role' : ''}';
    return _page(await ApiClient.getPage('/users?$q'), AppUser.fromJson);
  }

  static Future<AppUser> updateUser(
    int id, {
    String? name,
    String? designation,
    String? role,
  }) async => AppUser.fromJson(
    await ApiClient.put('/users/$id', {
      if (name != null) 'name': name,
      'designation': designation,
      if (role != null) 'role': role,
    }) as Map<String, dynamic>,
  );

  static Future<AppUser> setActive(int id, bool active) async =>
      AppUser.fromJson(
        await ApiClient.post(
          '/users/$id/${active ? 'activate' : 'deactivate'}',
          {},
        ) as Map<String, dynamic>,
      );

  /// Returns the one-time temporary password.
  static Future<String> resetUserPassword(int id) async {
    final r = await ApiClient.postRaw('/users/$id/reset-password', {});
    return r['temporary_password'] as String;
  }
}

typedef Assignee = TaskAssignee;
