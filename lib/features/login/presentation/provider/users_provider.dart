import 'package:flutter/foundation.dart';

import '../../data/model/login_model.dart';
import '../../data/repository/login_repository.dart';

/// Roles a user can have.
const List<String> kUserRoles = ['admin', 'manager', 'cashier'];

/// A draft coming out of the user form.
class UserDraft {
  const UserDraft({
    this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.isActive,
    this.password,
  });

  final int? id;
  final String username;
  final String fullName;
  final String role;
  final bool isActive;

  /// Non-empty to set/change the password.
  final String? password;
}

/// State/logic holder for the Users (admin) screen.
class UsersProvider extends ChangeNotifier {
  UsersProvider([LoginRepository? repository])
      : _repository = repository ?? LoginRepository();

  final LoginRepository _repository;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  List<LoginModel> _items = const [];
  List<LoginModel> get items => _items;

  int roleCount(String role) => _items.where((u) => u.role == role).length;
  int get activeCount => _items.where((u) => u.isActive).length;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.ensureSchema();
      _items = await _repository.getAll();
    } catch (e) {
      _error = _friendly(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> save(UserDraft draft) async {
    try {
      if (draft.id == null) {
        await _repository.createUser(
          username: draft.username,
          password: draft.password ?? '',
          fullName: draft.fullName,
          role: draft.role,
          isActive: draft.isActive,
        );
      } else {
        await _repository.updateUser(
          LoginModel(
            id: draft.id!,
            username: draft.username,
            fullName: draft.fullName,
            role: draft.role,
            isActive: draft.isActive,
          ),
          newPassword: draft.password,
        );
      }
      await load();
      return true;
    } catch (e) {
      _error = _friendly(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> delete(int id) async {
    try {
      await _repository.deleteUser(id);
      _items = _items.where((u) => u.id != id).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendly(e);
      notifyListeners();
      return false;
    }
  }

  String _friendly(Object e) {
    final t = e.toString();
    if (t.contains('23505')) {
      return 'That username is already taken.';
    }
    if (t.contains('42501')) {
      return 'Permission denied. Run '
          'lib/features/login/data/sql/seed_users.sql as a database superuser.';
    }
    if (t.contains('42P01')) {
      return 'The "users" table does not exist yet. Run '
          'lib/features/login/data/sql/seed_users.sql.';
    }
    return 'Something went wrong. Check the database connection.';
  }
}
