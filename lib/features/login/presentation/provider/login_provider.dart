import 'package:flutter/foundation.dart';

import '../../data/datasource/login_datasource.dart';
import '../../data/model/login_model.dart';
import '../../data/repository/login_repository.dart';
import '../../data/session_store.dart';

/// State/logic holder for the Login feature.
class LoginProvider extends ChangeNotifier {
  LoginProvider([LoginRepository? repository, SessionStore? session])
      : _repository = repository ?? LoginRepository(),
        _session = session ?? const SessionStore();

  final LoginRepository _repository;
  final SessionStore _session;

  bool _loading = false;
  bool get loading => _loading;

  /// True until [restore] has finished checking local storage.
  bool _restoring = true;
  bool get restoring => _restoring;

  String? _error;
  String? get error => _error;

  LoginModel? _currentUser;
  LoginModel? get currentUser => _currentUser;

  bool get isLoggedIn => _currentUser != null;

  /// Role of the signed-in user (`admin` / `manager` / `cashier`), or `null`.
  String? get role => _currentUser?.role;

  /// Loads any locally-stored session. Call once at startup.
  Future<void> restore() async {
    try {
      _currentUser = await _session.read();
    } catch (e) {
      debugPrint('LoginProvider.restore: $e');
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  /// Signs the user in against the `users` table.
  /// Returns `true` on success.
  Future<bool> login(String username, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.ensureSchema();
      final user = await _repository.login(username.trim(), password);
      if (user == null) {
        _error = 'Invalid username or password';
        _currentUser = null;
        return false;
      }
      _currentUser = user;
      try {
        await _session.save(user);
      } catch (e) {
        debugPrint('LoginProvider: could not persist session: $e');
      }
      return true;
    } on LoginSchemaException catch (e) {
      _error = e.message;
      _currentUser = null;
      return false;
    } catch (e) {
      _error = 'Login failed. Please check the database connection.';
      debugPrint('LoginProvider: $e');
      _currentUser = null;
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    _error = null;
    try {
      await _session.clear();
    } catch (e) {
      debugPrint('LoginProvider: could not clear session: $e');
    }
    notifyListeners();
  }
}
