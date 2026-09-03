/// Database configuration for the POS PostgreSQL connection.
///
/// Values can be overridden at build/run time with --dart-define, e.g.:
///   flutter run -d macos \
///     --dart-define=DB_HOST=192.168.1.10 \
///     --dart-define=DB_PASSWORD=secret
class DbConfig {
  const DbConfig._();

  /// Database server host.
  static const String host = String.fromEnvironment('DB_HOST', defaultValue: 'localhost');

  /// Database server port.
  static const int port = int.fromEnvironment('DB_PORT', defaultValue: 5432);

  /// Database name.
  static const String database = String.fromEnvironment('DB_NAME', defaultValue: 'pos');

  /// Database user.
  static const String username = String.fromEnvironment('DB_USER', defaultValue: 'posuser');

  /// Database password.
  static const String password = String.fromEnvironment('DB_PASSWORD', defaultValue: 'pos1234');

  /// Whether to require SSL. Set true for remote/production servers.
  static const bool useSsl =
      bool.fromEnvironment('DB_SSL', defaultValue: false);

  /// Connection / query timeout.
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration queryTimeout = Duration(seconds: 30);
}
