import '../datasource/product_catalog_datasource.dart';
import '../model/category_model.dart';
import '../model/inventory_type_model.dart';

/// Repository for the Product Catalog feature. Presentation layer depends on this.
class ProductCatalogRepository {
  ProductCatalogRepository([ProductCatalogDataSource? dataSource])
      : _dataSource = dataSource ?? const ProductCatalogDataSource();

  final ProductCatalogDataSource _dataSource;

  Future<void> ensureSchema() => _dataSource.ensureSchema();

  Future<List<CategoryModel>> getCategories() => _dataSource.fetchCategories();

  /// Inserts a new category (when `model.id == null`) or updates an existing one.
  Future<CategoryModel> saveCategory(CategoryModel model) => model.id == null
      ? _dataSource.insertCategory(model)
      : _dataSource.updateCategory(model);

  Future<void> deleteCategory(int id) => _dataSource.deleteCategory(id);

  Future<List<InventoryTypeModel>> getInventoryTypes() =>
      _dataSource.fetchInventoryTypes();

  /// Inserts a new inventory type (when `model.id == null`) or updates one.
  Future<InventoryTypeModel> saveInventoryType(InventoryTypeModel model) =>
      model.id == null
          ? _dataSource.insertInventoryType(model)
          : _dataSource.updateInventoryType(model);

  Future<void> deleteInventoryType(int id) =>
      _dataSource.deleteInventoryType(id);
}
