import 'package:postgres/postgres.dart';

import '../../../../config/backup_config.dart';
import '../../../../config/database/database_connection.dart';
import '../model/backup_settings_model.dart';

const _cols = 'enabled, supabase_url, supabase_key, last_backup_at, '
    'last_status, last_backup_ok';

/// Local storage for the cloud-backup configuration (single row, id = 1).
class BackupSettingsDataSource {
  const BackupSettingsDataSource();

  Connection get _conn => Database.instance.connection;

  Future<void> ensureSchema() async {
    try {
      await _conn.execute('''
        CREATE TABLE IF NOT EXISTS backup_settings (
          id             SMALLINT     PRIMARY KEY DEFAULT 1,
          enabled        BOOLEAN      NOT NULL DEFAULT FALSE,
          supabase_url   TEXT         NOT NULL DEFAULT '',
          supabase_key   TEXT         NOT NULL DEFAULT '',
          last_backup_at TIMESTAMPTZ,
          last_status    TEXT         NOT NULL DEFAULT '',
          last_backup_ok BOOLEAN      NOT NULL DEFAULT FALSE,
          CONSTRAINT backup_settings_one_row CHECK (id = 1)
        )
      ''');
      // Seed the single row with the built-in Supabase project (and turn
      // auto-backup on) — but only while the user has not set their own
      // credentials. Once `supabase_url` is non-blank the app never touches it.
      final enable = BackupConfig.autoEnabled && BackupConfig.hasDefaults;
      await _conn.execute(
        Sql.named('''
          INSERT INTO backup_settings (id, enabled, supabase_url, supabase_key)
          VALUES (1, @enabled, @url, @key)
          ON CONFLICT (id) DO UPDATE SET
            enabled      = EXCLUDED.enabled,
            supabase_url = EXCLUDED.supabase_url,
            supabase_key = EXCLUDED.supabase_key
          WHERE backup_settings.supabase_url = ''
        '''),
        parameters: {
          'enabled': enable,
          'url': BackupConfig.supabaseUrl.trim(),
          'key': BackupConfig.supabaseKey.trim(),
        },
      );
    } on ServerException catch (e) {
      if (e.code != '42501') rethrow;
    }
  }

  Future<BackupSettingsModel> fetch() async {
    await ensureSchema();
    final rows = await _conn.execute(
      'SELECT $_cols FROM backup_settings WHERE id = 1',
    );
    if (rows.isEmpty) return const BackupSettingsModel();
    return BackupSettingsModel.fromMap(rows.first.toColumnMap());
  }

  Future<BackupSettingsModel> saveConfig(BackupSettingsModel s) async {
    await ensureSchema();
    final rows = await _conn.execute(
      Sql.named('''
        UPDATE backup_settings SET
          enabled = @enabled,
          supabase_url = @supabase_url,
          supabase_key = @supabase_key
        WHERE id = 1
        RETURNING $_cols
      '''),
      parameters: s.toParams(),
    );
    return BackupSettingsModel.fromMap(rows.first.toColumnMap());
  }

  /// Records the outcome of a backup run.
  Future<BackupSettingsModel> markRun({
    required bool ok,
    required String status,
    DateTime? at,
  }) async {
    await ensureSchema();
    final rows = await _conn.execute(
      Sql.named('''
        UPDATE backup_settings SET
          last_backup_at = @at,
          last_status = @status,
          last_backup_ok = @ok
        WHERE id = 1
        RETURNING $_cols
      '''),
      parameters: {
        'at': at ?? DateTime.now(),
        'status': status,
        'ok': ok,
      },
    );
    return BackupSettingsModel.fromMap(rows.first.toColumnMap());
  }
}
