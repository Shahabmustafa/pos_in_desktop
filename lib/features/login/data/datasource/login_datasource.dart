import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:postgres/postgres.dart';

import '../../../../config/database/database_connection.dart';
import '../model/login_model.dart';

const String _baseUserColumns = 'id, username, full_name, role, is_active';

/// Thrown when the `users` table is missing and the DB user cannot create it.
class LoginSchemaException implements Exception {
  const LoginSchemaException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Talks to PostgreSQL for the Login feature.
class LoginDataSource {
  const LoginDataSource();

  /// Whether the `users` table has the optional `permissions` column. Set by
  /// [ensureSchema]; until then we assume it is absent so a login still works
  /// against an older schema. Process-wide (the schema does not change under
  /// us mid-run).
  static bool hasPermissionsColumn = false;

  /// Columns to SELECT / RETURN, with `permissions` only when it exists.
  static String get _userColumns => hasPermissionsColumn
      ? '$_baseUserColumns, permissions'
      : _baseUserColumns;

  /// Hashes a plaintext password to a SHA-256 hex string.
  static String hashPassword(String raw) =>
      sha256.convert(utf8.encode(raw)).toString();

  /// Makes sure the `users` table exists and has a default `admin` account.
  ///
  /// If the table is already there (e.g. created by db/seed_users.sql) this is
  /// a no-op. If it is missing and the connected DB user lacks `CREATE` on the
  /// schema, a [LoginSchemaException] is thrown with a fix hint instead of a
  /// raw Postgres error.
  Future<void> ensureSchema() async {
    final conn = Database.instance.connection;

    final exists = await _tableExists(conn);
    if (!exists) {
      try {
        await conn.execute('''
          CREATE TABLE IF NOT EXISTS users (
            id          SERIAL PRIMARY KEY,
            username    TEXT        NOT NULL UNIQUE,
            password    TEXT        NOT NULL,
            full_name   TEXT        NOT NULL DEFAULT '',
            role        TEXT        NOT NULL DEFAULT 'cashier',
            is_active   BOOLEAN     NOT NULL DEFAULT TRUE,
            permissions TEXT,
            created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
          )
        ''');
      } on ServerException catch (e) {
        if (e.code == '42501') {
          throw const LoginSchemaException(
            'Database not set up. Run '
            'lib/features/login/data/sql/seed_users.sql once.',
          );
        }
        rethrow;
      }
    }

    // Bring older installs up to date: the `permissions` column was added
    // later. This needs table ownership; ignore a privilege error so the app
    // still runs (custom permissions are then unavailable until a superuser
    // runs seed_users.sql / fix_permissions.sql).
    try {
      await conn.execute(
        'ALTER TABLE users ADD COLUMN IF NOT EXISTS permissions TEXT',
      );
    } on ServerException catch (e) {
      if (e.code != '42501') rethrow;
      debugPrint(
          'LoginDataSource: cannot add "permissions" column (not table owner).');
    }

    hasPermissionsColumn = await _columnExists(conn, 'users', 'permissions');

    // Seed the default admin. Ignore permission errors here so a read-only
    // app user can still log in against a table someone else populated.
    try {
      await conn.execute(
        Sql.named('''
          INSERT INTO users (username, password, full_name, role)
          VALUES (@username, @password, @full_name, @role)
          ON CONFLICT (username) DO NOTHING
        '''),
        parameters: {
          'username': 'admin',
          'password': hashPassword('admin123'),
          'full_name': 'Administrator',
          'role': 'admin',
        },
      );
    } on ServerException catch (e) {
      if (e.code != '42501') rethrow;
      debugPrint('LoginDataSource: skipped admin seed (no INSERT privilege).');
    }
  }

  Future<bool> _tableExists(Connection conn) async {
    final result = await conn.execute(
      "SELECT to_regclass('public.users') IS NOT NULL AS present",
    );
    return (result.first.toColumnMap()['present'] as bool?) ?? false;
  }

  Future<bool> _columnExists(
      Connection conn, String table, String column) async {
    try {
      final result = await conn.execute(
        Sql.named('''
          SELECT EXISTS (
            SELECT 1 FROM information_schema.columns
            WHERE table_schema = 'public'
              AND table_name = @table
              AND column_name = @column
          ) AS present
        '''),
        parameters: {'table': table, 'column': column},
      );
      return (result.first.toColumnMap()['present'] as bool?) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Returns the matching active user, or `null` when the credentials are wrong.
  Future<LoginModel?> authenticate(String username, String password) async {
    final result = await Database.instance.connection.execute(
      Sql.named('''
        SELECT $_userColumns
        FROM users
        WHERE username = @username
          AND password = @password
          AND is_active = TRUE
        LIMIT 1
      '''),
      parameters: {
        'username': username,
        'password': hashPassword(password),
      },
    );

    if (result.isEmpty) return null;
    return LoginModel.fromMap(result.first.toColumnMap());
  }

  /// All users, for admin screens.
  Future<List<LoginModel>> fetchAll() async {
    final result = await Database.instance.connection.execute(
      'SELECT $_userColumns FROM users ORDER BY username',
    );
    return result.map((row) => LoginModel.fromMap(row.toColumnMap())).toList();
  }

  Future<LoginModel> insertUser({
    required String username,
    required String password,
    required String fullName,
    required String role,
    required bool isActive,
    Set<String>? customPermissions,
  }) async {
    final withPerms = hasPermissionsColumn;
    final result = await Database.instance.connection.execute(
      Sql.named('''
        INSERT INTO users (username, password, full_name, role, is_active${withPerms ? ', permissions' : ''})
        VALUES (@username, @password, @full_name, @role, @is_active${withPerms ? ', @permissions' : ''})
        RETURNING $_userColumns
      '''),
      parameters: {
        'username': username,
        'password': hashPassword(password),
        'full_name': fullName,
        'role': role,
        'is_active': isActive,
        if (withPerms)
          'permissions': LoginModel.encodePermissions(customPermissions),
      },
    );
    return LoginModel.fromMap(result.first.toColumnMap());
  }

  /// Updates a user's profile fields. Pass [newPassword] to also change the
  /// password. Custom permissions are managed separately via [setPermissions]
  /// and are left untouched here.
  Future<LoginModel> updateUser(
    LoginModel user, {
    String? newPassword,
  }) async {
    final setPassword = newPassword != null && newPassword.isNotEmpty;
    final result = await Database.instance.connection.execute(
      Sql.named('''
        UPDATE users SET
          username = @username,
          full_name = @full_name,
          role = @role,
          is_active = @is_active
          ${setPassword ? ', password = @password' : ''}
        WHERE id = @id
        RETURNING $_userColumns
      '''),
      parameters: {
        'id': user.id,
        'username': user.username,
        'full_name': user.fullName,
        'role': user.role,
        'is_active': user.isActive,
        if (setPassword) 'password': hashPassword(newPassword),
      },
    );
    return LoginModel.fromMap(result.first.toColumnMap());
  }

  /// Sets (or clears, with `null`) a user's custom permission set.
  Future<LoginModel> setPermissions(int id, Set<String>? permissions) async {
    if (!hasPermissionsColumn) {
      throw const LoginSchemaException(
        'The "permissions" column is missing from the users table. Ask a '
        'database admin to run lib/features/login/data/sql/fix_permissions.sql '
        '(or seed_users.sql) once.',
      );
    }
    final result = await Database.instance.connection.execute(
      Sql.named('''
        UPDATE users SET permissions = @permissions
        WHERE id = @id
        RETURNING $_userColumns
      '''),
      parameters: {
        'id': id,
        'permissions': LoginModel.encodePermissions(permissions),
      },
    );
    return LoginModel.fromMap(result.first.toColumnMap());
  }

  Future<void> deleteUser(int id) async {
    await Database.instance.connection.execute(
      Sql.named('DELETE FROM users WHERE id = @id'),
      parameters: {'id': id},
    );
  }
}
