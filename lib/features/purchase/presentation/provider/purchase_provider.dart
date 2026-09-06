import 'package:flutter/foundation.dart';

import '../../data/model/purchase_model.dart';
import '../../data/model/purchase_refs.dart';
import '../../data/repository/purchase_repository.dart';

/// State/logic holder for the Purchase Invoice feature.
class PurchaseProvider extends ChangeNotifier {
  PurchaseProvider([PurchaseRepository? repository])
      : _repository = repository ?? PurchaseRepository();

  final PurchaseRepository _repository;

  bool _bootstrapped = false;

  bool _loading = false;
  bool get loading => _loading;

  bool _saving = false;
  bool get saving => _saving;

  String? _error;
  String? get error => _error;

  List<PurchaseModel> _items = const [];
  List<PurchaseModel> get items => _items;

  PurchaseModel? _lastSaved;

  /// The purchase invoice most recently saved (with its assigned number), for
  /// printing a receipt right after a save.
  PurchaseModel? get lastSaved => _lastSaved;

  List<CompanyRef> _companies = const [];

  /// Suppliers for the invoice's company picker (from the Company feature).
  List<CompanyRef> get companies => _companies;

  List<ProductRef> _products = const [];

  /// Products for the invoice line picker (from the Stock Inventory feature).
  List<ProductRef> get products => _products;

  int get invoiceCount => _items.length;

  double get totalPurchases =>
      _items.fold<double>(0, (a, p) => a + p.grandTotal);

  /// Suggested next invoice number, e.g. "PI-0004".
  String nextNumber() => 'PI-${(_items.length + 1).toString().padLeft(4, '0')}';

  Future<void> load() async {
    if (!_bootstrapped) {
      _loading = true;
      notifyListeners();
    }
    _error = null;
    try {
      await _repository.ensureSchema();
      _companies = await _repository.getCompanies();
      _products = await _repository.getProducts();
      _items = await _repository.getAll();
      _bootstrapped = true;
    } catch (e) {
      _error = _friendly(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> save(PurchaseModel model) async {
    _saving = true;
    notifyListeners();
    try {
      _lastSaved = await _repository.save(model);
      await load();
      return true;
    } catch (e) {
      _error = _friendly(e);
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  Future<bool> delete(int id) async {
    try {
      await _repository.delete(id);
      _items = _items.where((p) => p.id != id).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendly(e);
      notifyListeners();
      return false;
    }
  }

  String _friendly(Object e) {
    final t = e.toString();
    if (t.contains('42501')) {
      return 'Permission denied. Run '
          'lib/features/purchase/data/sql/purchase.sql as a database superuser.';
    }
    if (t.contains('42P01')) {
      return 'The "purchase_invoice" tables do not exist yet. Run '
          'lib/features/purchase/data/sql/purchase.sql.';
    }
    return 'Something went wrong. Check the database connection.';
  }
}
