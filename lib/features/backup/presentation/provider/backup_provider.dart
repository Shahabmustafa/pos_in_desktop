import 'package:flutter/foundation.dart';

import '../../../../config/format.dart';
import '../../data/backup_service.dart';
import '../../data/model/backup_settings_model.dart';
import '../../data/repository/backup_repository.dart';
import '../../backup_scheduler.dart';

/// State/logic holder for the Backup Settings screen.
class BackupProvider extends ChangeNotifier {
  BackupProvider([BackupRepository? repository])
      : _repository = repository ?? BackupRepository();

  final BackupRepository _repository;

  bool _loading = false;
  bool get loading => _loading;

  bool _busy = false;

  /// True while a backup or restore is running.
  bool get busy => _busy;

  String? _error;
  String? get error => _error;

  String? _message;

  /// Result of the last manual action, shown as a banner.
  String? get message => _message;

  BackupSettingsModel _settings = const BackupSettingsModel();
  BackupSettingsModel get settings => _settings;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _settings = await _repository.getSettings();
    } catch (e) {
      _error = _friendly(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> saveConfig(BackupSettingsModel edited) async {
    _busy = true;
    _error = null;
    _message = null;
    notifyListeners();
    try {
      _settings = await _repository.saveConfig(edited);
      BackupScheduler.instance.reconfigure(_settings);
      _message = 'Backup settings saved';
      return true;
    } catch (e) {
      _error = _friendly(e);
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> backupNow() async {
    if (_busy) return;
    _busy = true;
    _error = null;
    _message = null;
    notifyListeners();
    try {
      final service = _repository.serviceFor(_settings);
      final outcome = await service.backup();
      final status = 'Backed up ${outcome.summary}';
      _settings = await _repository.markRun(ok: true, status: status);
      _message = '$status · ${Fmt.date(DateTime.now())}';
    } catch (e) {
      final msg = _friendly(e);
      _error = msg;
      try {
        _settings = await _repository.markRun(ok: false, status: msg);
      } catch (_) {/* leave the timestamp alone */}
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Writes every table to CSV files under [dir]. Returns the folder path on
  /// success, or `null` on failure (see [error]).
  Future<String?> exportCsv(String dir) async {
    if (_busy) return null;
    _busy = true;
    _error = null;
    _message = null;
    notifyListeners();
    try {
      final service = _repository.serviceFor(_settings);
      final out = await service.exportCsv(dir);
      _message = 'Saved ${out.rows} row(s) to ${out.tables} CSV file(s)';
      return out.folder;
    } catch (e) {
      _error = _friendly(e);
      return null;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Permanently clears the local business data (keeps login + shop header).
  Future<void> clearLocal() async {
    if (_busy) return;
    _busy = true;
    _error = null;
    _message = null;
    notifyListeners();
    try {
      final service = _repository.serviceFor(_settings);
      final removed = await service.clearLocal();
      _message = 'Cleared $removed row(s). Restart the app.';
    } catch (e) {
      _error = _friendly(e);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> restoreNow() async {
    if (_busy) return;
    _busy = true;
    _error = null;
    _message = null;
    notifyListeners();
    try {
      final service = _repository.serviceFor(_settings);
      final outcome = await service.restore();
      _message = 'Restored ${outcome.summary}. Restart the app to see it.';
    } catch (e) {
      _error = _friendly(e);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  String _friendly(Object e) {
    if (e is BackupException) return e.message;
    final t = e.toString();
    if (t.contains('42501')) {
      return 'Permission denied on the local database.';
    }
    if (t.contains('SocketException') || t.contains('Failed host lookup')) {
      return 'Cannot reach Supabase. Check the URL and your internet.';
    }
    return 'Something went wrong: $t';
  }
}
