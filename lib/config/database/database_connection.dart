import 'package:postgres/postgres.dart';
import '../db_config.dart';

/// Single shared PostgreSQL connection for the whole app.
///
/// Usage:
///   await Database.instance.open();          // once, at startup
///   final rows = await Database.instance.connection.execute('SELECT 1');
///   await Database.instance.close();         // on app exit
class Database {
  Database._();

  static final Database instance = Database._();

  Connection? _connection;

  /// The live connection. Throws if [open] has not been called yet.
  Connection get connection {
    final conn = _connection;
    if (conn == null || !conn.isOpen) {
      throw StateError('Database not connected. Call Database.instance.open() first.');
    }
    return conn;
  }

  bool get isOpen => _connection?.isOpen ?? false;

  /// Opens the connection using [DbConfig]. Safe to call more than once.
  Future<void> open() async {
    if (isOpen) return;

    _connection = await Connection.open(
      Endpoint(
        host: DbConfig.host,
        port: DbConfig.port,
        database: DbConfig.database,
        username: DbConfig.username,
        password: DbConfig.password,
      ),
      settings: ConnectionSettings(
        sslMode: DbConfig.useSsl ? SslMode.require : SslMode.disable,
        connectTimeout: DbConfig.connectTimeout,
        queryTimeout: DbConfig.queryTimeout,
        // Desktop apps have a stable app-name; helps when inspecting pg_stat_activity.
        applicationName: 'pos-desktop',
      ),
    );
  }

  /// Quick connectivity check. Returns true if a simple query succeeds.
  Future<bool> ping() async {
    try {
      await connection.execute('SELECT 1');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> close() async {
    await _connection?.close();
    _connection = null;
  }
}
