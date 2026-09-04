import 'package:flutter/foundation.dart';

import '../../data/model/login_model.dart';
import '../../data/permissions.dart';
import '../../data/repository/login_repository.dart';

/// State for the Permissions (admin) screen: pick a user on the left, edit
/// their access on the right, save.
class PermissionsProvider extends ChangeNotifier {
  PermissionsProvider([LoginRepository? repository])
      : _repository = repository ?? LoginRepository();

  final LoginRepository _repository;

  bool _loading = false;
  bool get loading => _loading;

  bool _saving = false;
  bool get saving => _saving;

  String? _error;
  String? get error => _error;

  List<LoginModel> _users = const [];
  List<LoginModel> get users => _users;

  LoginModel? _selected;
  LoginModel? get selected => _selected;

  /// `true` when the selected user is on a custom set, `false` when they follow
  /// their role defaults.
  bool _customMode = false;
  bool get customMode => _customMode;

  final Set<String> _draft = <String>{};

  /// The permission keys currently ticked in the editor.
  Set<String> get draft => Set.unmodifiable(_draft);

  bool _dirty = false;
  bool get dirty => _dirty;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.ensureSchema();
      _users = await _repository.getAll();
      if (_selected != null) {
        _selected = _users.cast<LoginModel?>().firstWhere(
              (u) => u?.id == _selected!.id,
              orElse: () => null,
            );
      }
      _selected ??= _users.isNotEmpty ? _users.first : null;
      _resetDraft();
    } catch (e) {
      _error = _friendly(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void select(LoginModel user) {
    if (_selected?.id == user.id) return;
    _selected = user;
    _resetDraft();
    notifyListeners();
  }

  void _resetDraft() {
    final user = _selected;
    _customMode = user?.hasCustomPermissions ?? false;
    _draft
      ..clear()
      ..addAll(user?.effectivePermissions ?? const <String>{});
    _dirty = false;
  }

  /// Switch between "role defaults" and "custom access".
  void setCustomMode(bool custom) {
    if (_customMode == custom) return;
    _customMode = custom;
    if (!custom) {
      // Preview the role defaults; save() will clear the custom set.
      final role = _selected?.role ?? '';
      _draft
        ..clear()
        ..addAll(defaultPermissionsFor(role));
    }
    _dirty = true;
    notifyListeners();
  }

  bool has(String permissionKey) => _draft.contains(permissionKey);

  void toggle(String permissionKey, bool granted) {
    _customMode = true;
    if (granted) {
      _draft.add(permissionKey);
    } else {
      _draft.remove(permissionKey);
    }
    _dirty = true;
    notifyListeners();
  }

  /// Tick / untick every action of one feature at once.
  void toggleFeature(FeaturePermission feature, bool granted) {
    _customMode = true;
    for (final key in feature.permissionKeys) {
      if (granted) {
        _draft.add(key);
      } else {
        _draft.remove(key);
      }
    }
    _dirty = true;
    notifyListeners();
  }

  void grantAll() {
    _customMode = true;
    _draft
      ..clear()
      ..addAll(allPermissionKeys());
    _dirty = true;
    notifyListeners();
  }

  void clearAll() {
    _customMode = true;
    _draft.clear();
    _dirty = true;
    notifyListeners();
  }

  Future<bool> save() async {
    final user = _selected;
    if (user == null) return false;
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      final Set<String>? payload = _customMode ? Set.of(_draft) : null;
      final updated = await _repository.setPermissions(user.id, payload);
      _users = [
        for (final u in _users) if (u.id == updated.id) updated else u,
      ];
      _selected = updated;
      _resetDraft();
      return true;
    } catch (e) {
      _error = _friendly(e);
      notifyListeners();
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  int roleCount(String role) => _users.where((u) => u.role == role).length;
  int get customCount => _users.where((u) => u.hasCustomPermissions).length;

  String _friendly(Object e) {
    final t = e.toString();
    if (t.contains('42501')) {
      return 'Permission denied by the database. Run '
          'lib/features/login/data/sql/seed_users.sql as a superuser.';
    }
    if (t.contains('42P01')) {
      return 'The "users" table does not exist yet. Run '
          'lib/features/login/data/sql/seed_users.sql.';
    }
    if (t.contains('42703')) {
      return 'The "permissions" column is missing. Run '
          'lib/features/login/data/sql/seed_users.sql to add it.';
    }
    return 'Something went wrong. Check the database connection.';
  }
}
