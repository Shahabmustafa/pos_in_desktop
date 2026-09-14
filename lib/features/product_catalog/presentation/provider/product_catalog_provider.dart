import 'package:flutter/foundation.dart';

import '../../data/model/category_model.dart';
import '../../data/model/inventory_type_model.dart';
import '../../data/repository/product_catalog_repository.dart';

/// State/logic holder for the Product Catalog feature (categories + types).
class ProductCatalogProvider extends ChangeNotifier {
  ProductCatalogProvider([ProductCatalogRepository? repository])
      : _repository = repository ?? ProductCatalogRepository();

  final ProductCatalogRepository _repository;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  List<CategoryModel> _categories = const [];
  List<CategoryModel> get categories => _categories;

  List<InventoryTypeModel> _inventoryTypes = const [];
  List<InventoryTypeModel> get inventoryTypes => _inventoryTypes;

  int get activeCategoryCount => _categories.where((c) => c.isActive).length;
  int get activeTypeCount => _inventoryTypes.where((t) => t.isActive).length;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.ensureSchema();
      _categories = await _repository.getCategories();
      _inventoryTypes = await _repository.getInventoryTypes();
    } catch (e) {
      _error = _friendly(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> saveCategory(CategoryModel model) async {
    try {
      await _repository.saveCategory(model);
      await load();
      return true;
    } catch (e) {
      _error = _friendly(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCategory(int id) async {
    try {
      await _repository.deleteCategory(id);
      _categories = _categories.where((c) => c.id != id).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendly(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> saveInventoryType(InventoryTypeModel model) async {
    try {
      await _repository.saveInventoryType(model);
      await load();
      return true;
    } catch (e) {
      _error = _friendly(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteInventoryType(int id) async {
    try {
      await _repository.deleteInventoryType(id);
      _inventoryTypes = _inventoryTypes.where((t) => t.id != id).toList();
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
    if (t.contains('23505')) {
      return 'That name already exists. Pick a different one.';
    }
    if (t.contains('23503')) {
      return 'This is assigned to one or more products and cannot be '
          'deleted. Mark it inactive instead, or reassign those products '
          'first.';
    }
    if (t.contains('42501')) {
      return 'Permission denied. Run '
          'lib/features/product_catalog/data/sql/product_catalog.sql as a '
          'database superuser.';
    }
    if (t.contains('42P01')) {
      return 'The catalog tables do not exist yet. Run '
          'lib/features/product_catalog/data/sql/product_catalog.sql.';
    }
    return 'Something went wrong. Check the database connection.';
  }
}
