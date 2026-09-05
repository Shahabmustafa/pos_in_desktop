import 'package:flutter/foundation.dart';

import '../../data/model/named_ref.dart';
import '../../data/model/stock_item_model.dart';
import '../../data/repository/stock_inventory_repository.dart';

/// State/logic holder for the Stock Inventory feature.
class StockInventoryProvider extends ChangeNotifier {
  StockInventoryProvider([StockInventoryRepository? repository])
      : _repository = repository ?? StockInventoryRepository();

  final StockInventoryRepository _repository;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  List<StockItemModel> _items = const [];
  List<StockItemModel> get items => _items;

  List<NamedRef> _companies = const [];
  List<NamedRef> _categories = const [];
  List<NamedRef> _inventoryTypes = const [];

  /// Companies for the form's company picker (from the Company feature).
  List<NamedRef> get companies => _companies;

  /// Categories for the form's category picker (from the Product Catalog feature).
  List<NamedRef> get categories => _categories;

  /// Inventory types for the form's type picker (from the Product Catalog feature).
  List<NamedRef> get inventoryTypes => _inventoryTypes;

  int get activeCount => _items.where((i) => i.isActive).length;

  /// Distinct categories currently used by at least one product.
  int get categoryCount => _items
      .map((i) => i.category.trim())
      .where((c) => c.isNotEmpty)
      .toSet()
      .length;

  double get stockValue =>
      _items.fold<double>(0, (a, i) => a + i.purchasePrice * i.quantity);

  /// Total units on hand across every product.
  double get unitsOnHand =>
      _items.fold<double>(0, (a, i) => a + i.quantity);

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.ensureSchema();
      _companies = await _repository.getCompanies();
      _categories = await _repository.getCategories();
      _inventoryTypes = await _repository.getInventoryTypes();
      _items = _resolveNames(await _repository.getAll());
    } catch (e) {
      _error = _friendly(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Fills each item's display names from the master lists using its foreign
  /// keys, keeping the stored snapshot text when there is no id / match.
  List<StockItemModel> _resolveNames(List<StockItemModel> items) {
    String nameFor(List<NamedRef> refs, int? id, String fallback) {
      if (id == null) return fallback;
      for (final r in refs) {
        if (r.id == id) return r.name;
      }
      return fallback;
    }

    return [
      for (final i in items)
        i.copyWith(
          companyName: nameFor(_companies, i.companyId, i.companyName),
          category: nameFor(_categories, i.categoryId, i.category),
          inventoryType:
              nameFor(_inventoryTypes, i.inventoryTypeId, i.inventoryType),
        ),
    ];
  }

  Future<bool> save(StockItemModel model) async {
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
      _items = _items.where((i) => i.id != id).toList();
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
          'lib/features/stock_inventory/data/sql/stock_inventory.sql as a '
          'database superuser.';
    }
    if (t.contains('42P01')) {
      return 'The "stock_item" table does not exist yet. Run '
          'lib/features/stock_inventory/data/sql/stock_inventory.sql.';
    }
    return 'Something went wrong. Check the database connection.';
  }
}
