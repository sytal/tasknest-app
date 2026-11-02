import '../models/project.dart';
import 'api_client.dart';

class ProjectService {
  static Future<List<Project>> list() async {
    final data = await ApiClient.get('/projects');
    final items = (data as List<dynamic>? ?? []);
    return items
        .map((e) => Project.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<Project> create({
    required String name,
    String? description,
  }) async {
    final data = await ApiClient.post('/projects', {
      'name': name,
      'description': description,
    });
    return Project.fromJson(data as Map<String, dynamic>);
  }

  static Future<Project> update({
    required int id,
    required String name,
    String? description,
  }) async {
    final data = await ApiClient.put('/projects/$id', {
      'name': name,
      'description': description,
    });
    return Project.fromJson(data as Map<String, dynamic>);
  }

  static Future<void> delete(int id) async {
    await ApiClient.delete('/projects/$id');
  }

  static Future<void> addMember({
    required int projectId,
    required int userId,
    required String projectRole,
  }) async {
    await ApiClient.post('/projects/$projectId/members', {
      'user_id': userId,
      'project_role': projectRole,
    });
  }

  static Future<void> updateMemberRole({
    required int projectId,
    required int userId,
    required String projectRole,
  }) async {
    await ApiClient.put('/projects/$projectId/members/$userId', {
      'project_role': projectRole,
    });
  }

  static Future<void> removeMember({
    required int projectId,
    required int userId,
  }) async {
    await ApiClient.delete('/projects/$projectId/members/$userId');
  }
}
