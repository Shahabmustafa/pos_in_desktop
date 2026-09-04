import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'model/login_model.dart';

/// Persists the signed-in user locally so the session survives an app restart.
///
/// Only non-sensitive fields are stored (id, username, name, role, active) —
/// never the password or its hash.
class SessionStore {
  const SessionStore();

  static const String _key = 'pos.session.user';

  Future<void> save(LoginModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(user.toMap()));
  }

  Future<LoginModel?> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return LoginModel.fromMap(map);
    } catch (_) {
      await clear();
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
