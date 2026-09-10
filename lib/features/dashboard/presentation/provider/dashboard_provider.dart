import 'package:flutter/foundation.dart';

import '../../data/model/dashboard_model.dart';
import '../../data/repository/dashboard_repository.dart';

/// State/logic holder for the Dashboard feature.
class DashboardProvider extends ChangeNotifier {
  DashboardProvider([DashboardRepository? repository])
      : _repository = repository ?? DashboardRepository();

  final DashboardRepository _repository;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  DashboardSummary _summary = DashboardSummary.empty;
  DashboardSummary get summary => _summary;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _summary = await _repository.getSummary();
    } catch (e) {
      _error = _friendly(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  String _friendly(Object e) {
    final t = e.toString();
    if (t.contains('Database not connected')) {
      return 'Not connected to the database. Check the connection and retry.';
    }
    if (t.contains('42501')) {
      return 'Permission denied reading the database.';
    }
    return 'Could not load the dashboard. Check the database connection.';
  }
}
