import '../backup_service.dart';
import '../datasource/backup_settings_datasource.dart';
import '../model/backup_settings_model.dart';

/// Repository for the cloud-backup feature.
class BackupRepository {
  BackupRepository([BackupSettingsDataSource? dataSource])
      : _dataSource = dataSource ?? const BackupSettingsDataSource();

  final BackupSettingsDataSource _dataSource;

  Future<BackupSettingsModel> getSettings() => _dataSource.fetch();

  Future<BackupSettingsModel> saveConfig(BackupSettingsModel s) =>
      _dataSource.saveConfig(s);

  Future<BackupSettingsModel> markRun({
    required bool ok,
    required String status,
    DateTime? at,
  }) =>
      _dataSource.markRun(ok: ok, status: status, at: at);

  /// Builds a service for the given credentials. Overridable in tests.
  BackupService serviceFor(BackupSettingsModel s) => BackupService(
        supabaseUrl: s.supabaseUrl,
        supabaseKey: s.supabaseKey,
      );
}
