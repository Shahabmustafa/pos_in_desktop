import 'dart:async';

import 'package:flutter/foundation.dart';

import 'data/model/backup_settings_model.dart';
import 'data/repository/backup_repository.dart';

/// Runs the Supabase backup every [BackupSettingsModel.intervalHours] while the
/// desktop app is open.
///
/// Started once from `main()`. The Backup Settings screen calls [reconfigure]
/// whenever the credentials or the enabled flag change.
class BackupScheduler {
  BackupScheduler._();

  static final BackupScheduler instance = BackupScheduler._();

  final BackupRepository _repository = BackupRepository();

  Timer? _timer;
  BackupSettingsModel _settings = const BackupSettingsModel();
  bool _running = false;

  /// Loads the saved settings and arms the timer. Safe to call once at startup;
  /// failures are swallowed so the app always starts.
  Future<void> start() async {
    try {
      _settings = await _repository.getSettings();
    } catch (_) {
      return;
    }
    _arm();
    // Catch up if the machine was off for more than one interval.
    if (_settings.isDueNow) {
      unawaited(_runSoon());
    }
  }

  /// Re-reads [settings] (called after the user edits them) and re-arms.
  void reconfigure(BackupSettingsModel settings) {
    _settings = settings;
    _arm();
  }

  void _arm() {
    _timer?.cancel();
    if (!_settings.enabled || !_settings.isConfigured) return;
    _timer = Timer.periodic(
      const Duration(hours: BackupSettingsModel.intervalHours),
      (_) => _runSoon(),
    );
  }

  Future<void> _runSoon() async {
    if (_running) return;
    if (!_settings.enabled || !_settings.isConfigured) return;
    _running = true;
    try {
      final service = _repository.serviceFor(_settings);
      final outcome = await service.backup();
      _settings = await _repository.markRun(
        ok: true,
        status: 'Auto-backup: ${outcome.summary}',
      );
    } catch (e) {
      debugPrint('BackupScheduler: auto-backup failed: $e');
      try {
        _settings = await _repository.markRun(ok: false, status: '$e');
      } catch (_) {/* ignore */}
    } finally {
      _running = false;
    }
  }

  @visibleForTesting
  void stop() {
    _timer?.cancel();
    _timer = null;
  }
}
