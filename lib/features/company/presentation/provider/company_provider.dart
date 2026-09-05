import 'package:flutter/foundation.dart';

import '../../data/model/company_model.dart';
import '../../data/repository/company_repository.dart';

/// State/logic holder for the Company feature.
class CompanyProvider extends ChangeNotifier {
  CompanyProvider([CompanyRepository? repository])
      : _repository = repository ?? CompanyRepository();

  final CompanyRepository _repository;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  List<CompanyModel> _items = const [];
  List<CompanyModel> get items => _items;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.ensureSchema();
      _items = await _repository.getAll();
    } catch (e) {
      _error = _friendly(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Creates or updates a company, then refreshes the list.
  /// Returns `true` on success.
  Future<bool> save(CompanyModel model) async {
    try {
      await _repository.save(model);
      await load();
      return true;
    } catch (e) {
      _error = _friendly(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> delete(int id) async {
    try {
      await _repository.delete(id);
      _items = _items.where((c) => c.id != id).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendly(e);
      notifyListeners();
      return false;
    }
  }

  String _friendly(Object e) {
    final text = e.toString();
    if (text.contains('42501')) {
      return 'Permission denied. Run lib/features/company/data/sql/company.sql '
          'as a database superuser.';
    }
    if (text.contains('42P01')) {
      return 'The "company" table does not exist yet. Run '
          'lib/features/company/data/sql/company.sql.';
    }
    return 'Something went wrong. Check the database connection.';
  }
}
