import 'package:flutter/foundation.dart';

import '../../data/model/customer_model.dart';
import '../../data/repository/customer_repository.dart';

/// State/logic holder for the Customer feature.
class CustomerProvider extends ChangeNotifier {
  CustomerProvider([CustomerRepository? repository])
      : _repository = repository ?? CustomerRepository();

  final CustomerRepository _repository;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  List<CustomerModel> _items = const [];
  List<CustomerModel> get items => _items;

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

  /// Creates or updates a customer, then refreshes the list.
  /// Returns `true` on success.
  Future<bool> save(CustomerModel model) async {
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
      return 'Permission denied. Run lib/features/customer/data/sql/customer.sql '
          'as a database superuser.';
    }
    if (text.contains('42P01')) {
      return 'The "customer" table does not exist yet. Run '
          'lib/features/customer/data/sql/customer.sql.';
    }
    return 'Something went wrong. Check the database connection.';
  }
}
