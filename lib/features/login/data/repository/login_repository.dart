import '../datasource/login_datasource.dart';
import '../model/login_model.dart';

/// Repository for the Login feature. Presentation layer depends on this.
class LoginRepository {
  LoginRepository([LoginDataSource? dataSource])
      : _dataSource = dataSource ?? const LoginDataSource();

  final LoginDataSource _dataSource;

  /// Creates/seeds the `users` table.
  Future<void> ensureSchema() => _dataSource.ensureSchema();

  /// Attempts a login. Returns the user on success, `null` on bad credentials.
  Future<LoginModel?> login(String username, String password) =>
      _dataSource.authenticate(username, password);

  Future<List<LoginModel>> getAll() => _dataSource.fetchAll();

  Future<LoginModel> createUser({
    required String username,
    required String password,
    required String fullName,
    required String role,
    required bool isActive,
    Set<String>? customPermissions,
  }) =>
      _dataSource.insertUser(
        username: username,
        password: password,
        fullName: fullName,
        role: role,
        isActive: isActive,
        customPermissions: customPermissions,
      );

  Future<LoginModel> updateUser(LoginModel user, {String? newPassword}) =>
      _dataSource.updateUser(user, newPassword: newPassword);

  Future<void> deleteUser(int id) => _dataSource.deleteUser(id);

  /// Assigns a custom permission set, or clears it (`null`) to fall back to the
  /// user's role defaults.
  Future<LoginModel> setPermissions(int id, Set<String>? permissions) =>
      _dataSource.setPermissions(id, permissions);
}
