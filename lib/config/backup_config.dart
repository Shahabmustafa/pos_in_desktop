/// Default Supabase project used for the cloud backup.
///
/// These are baked in so backup works out of the box — the app seeds them into
/// `backup_settings` on first run and turns auto-backup on. The user can still
/// change them on the Backup screen; once changed, the app never overwrites
/// their values.
///
/// Override at build time if needed:
///   flutter run -d macos \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_KEY=sb_publishable_xxx
///
/// The key here is a **publishable** key (safe to ship in a client app). Anyone
/// with it can read or overwrite the backup, so use a private Supabase project.
/// For stricter access, paste a `service_role` key on the Backup screen instead.
class BackupConfig {
  const BackupConfig._();

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://wgxxssabnjvqsinkggsq.supabase.co',
  );

  static const String supabaseKey = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: 'sb_publishable__XQSFrsL02vEohAkjYhSPQ_gpIB1HCO',
  );

  /// Turn auto-backup on automatically when the defaults above are present.
  static const bool autoEnabled = true;

  static bool get hasDefaults =>
      supabaseUrl.trim().isNotEmpty && supabaseKey.trim().isNotEmpty;
}
