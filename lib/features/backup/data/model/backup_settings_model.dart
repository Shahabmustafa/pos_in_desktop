/// Local-only configuration for the Supabase cloud backup.
///
/// Stored as a single row (`backup_settings`, id = 1). The Supabase key never
/// leaves this machine and is deliberately NOT part of the backup itself.
class BackupSettingsModel {
  const BackupSettingsModel({
    this.enabled = false,
    this.supabaseUrl = '',
    this.supabaseKey = '',
    this.lastBackupAt,
    this.lastStatus = '',
    this.lastBackupOk = false,
  });

  /// When true a backup runs every [BackupSettingsModel.intervalHours] while the
  /// app is open.
  final bool enabled;

  /// e.g. `https://abcd1234.supabase.co`.
  final String supabaseUrl;

  /// Supabase `service_role` (or `anon`) API key.
  final String supabaseKey;

  final DateTime? lastBackupAt;

  /// Short outcome of the last run (`'Backed up 812 rows'` or an error).
  final String lastStatus;
  final bool lastBackupOk;

  /// Fixed auto-backup cadence.
  static const int intervalHours = 6;

  bool get isConfigured =>
      supabaseUrl.trim().isNotEmpty && supabaseKey.trim().isNotEmpty;

  bool get isDueNow {
    if (!enabled || !isConfigured) return false;
    final last = lastBackupAt;
    if (last == null) return true;
    return DateTime.now().difference(last).inMinutes >= intervalHours * 60;
  }

  factory BackupSettingsModel.fromMap(Map<String, dynamic> map) {
    return BackupSettingsModel(
      enabled: (map['enabled'] as bool?) ?? false,
      supabaseUrl: (map['supabase_url'] as String?) ?? '',
      supabaseKey: (map['supabase_key'] as String?) ?? '',
      lastBackupAt: map['last_backup_at'] is DateTime
          ? map['last_backup_at'] as DateTime
          : DateTime.tryParse('${map['last_backup_at'] ?? ''}'),
      lastStatus: (map['last_status'] as String?) ?? '',
      lastBackupOk: (map['last_backup_ok'] as bool?) ?? false,
    );
  }

  /// Parameters for the settings UPDATE (`id` is fixed at 1).
  Map<String, dynamic> toParams() => {
        'enabled': enabled,
        'supabase_url': supabaseUrl.trim(),
        'supabase_key': supabaseKey.trim(),
      };

  BackupSettingsModel copyWith({
    bool? enabled,
    String? supabaseUrl,
    String? supabaseKey,
    DateTime? lastBackupAt,
    String? lastStatus,
    bool? lastBackupOk,
  }) {
    return BackupSettingsModel(
      enabled: enabled ?? this.enabled,
      supabaseUrl: supabaseUrl ?? this.supabaseUrl,
      supabaseKey: supabaseKey ?? this.supabaseKey,
      lastBackupAt: lastBackupAt ?? this.lastBackupAt,
      lastStatus: lastStatus ?? this.lastStatus,
      lastBackupOk: lastBackupOk ?? this.lastBackupOk,
    );
  }
}
