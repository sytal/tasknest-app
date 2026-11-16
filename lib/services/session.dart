import 'package:flutter/foundation.dart';

import '../models/user.dart';
import 'api_client.dart';
import 'auth_service.dart';

/// Holds the currently logged-in user for the whole app.
class Session extends ChangeNotifier {
  AppUser? currentUser;

  bool get isLoggedIn => currentUser != null;

  Future<void> login(String email, String password) async {
    currentUser = await AuthService.login(email, password);
    notifyListeners();
  }

  Future<bool> tryRestore() async {
    final hasToken = await AuthService.hasToken();
    if (!hasToken) return false;
    try {
      currentUser = await AuthService.me();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      // Only drop the token when the server says it is invalid.
      if (e.statusCode == 401) await ApiClient.setToken(null);
      currentUser = null;
      return false;
    } catch (_) {
      // Network error: keep the token so a retry/reload can restore the session.
      currentUser = null;
      return false;
    }
  }

  /// Replaces the current user (e.g. after an avatar upload/removal) and
  /// notifies listeners so the UI refreshes everywhere the user is shown.
  void updateUser(AppUser user) {
    currentUser = user;
    notifyListeners();
  }

  Future<void> logout() async {
    await AuthService.logout();
    currentUser = null;
    notifyListeners();
  }
}
