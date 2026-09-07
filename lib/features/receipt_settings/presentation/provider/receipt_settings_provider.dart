import 'package:flutter/foundation.dart';

import '../../data/model/receipt_settings_model.dart';
import '../../data/repository/receipt_settings_repository.dart';

/// State/logic holder for the Receipt Settings screen.
class ReceiptSettingsProvider extends ChangeNotifier {
  ReceiptSettingsProvider([ReceiptSettingsRepository? repository])
      : _repository = repository ?? ReceiptSettingsRepository();

  final ReceiptSettingsRepository _repository;

  bool _loading = false;
  bool get loading => _loading;

  bool _saving = false;
  bool get saving => _saving;

  String? _error;
  String? get error => _error;

  ReceiptSettingsModel _settings = const ReceiptSettingsModel();
  ReceiptSettingsModel get settings => _settings;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.ensureSchema();
      _settings = await _repository.get();
      ReceiptSettingsModel.current = _settings;
    } catch (e) {
      _error = _friendly(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Persists [model], refreshes the cached [ReceiptSettingsModel.current] so
  /// the next receipt uses it, and returns `true` on success.
  Future<bool> save(ReceiptSettingsModel model) async {
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      _settings = await _repository.save(model);
      ReceiptSettingsModel.current = _settings;
      return true;
    } catch (e) {
      _error = _friendly(e);
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  String _friendly(Object e) {
    final text = e.toString();
    if (text.contains('42501')) {
      return 'Permission denied. Run '
          'lib/features/receipt_settings/data/sql/receipt_settings.sql '
          'as a database superuser.';
    }
    if (text.contains('42P01')) {
      return 'The "receipt_settings" table does not exist yet. Run '
          'lib/features/receipt_settings/data/sql/receipt_settings.sql.';
    }
    return 'Something went wrong. Check the database connection.';
  }
}
