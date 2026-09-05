import '../datasource/stock_inventory_datasource.dart';
import '../model/named_ref.dart';
import '../model/stock_item_model.dart';

/// Repository for the Stock Inventory feature. Presentation layer depends on this.
class StockInventoryRepository {
  StockInventoryRepository([StockInventoryDataSource? dataSource])
      : _dataSource = dataSource ?? const StockInventoryDataSource();

  final StockInventoryDataSource _dataSource;

  Future<void> ensureSchema() => _dataSource.ensureSchema();

  Future<List<StockItemModel>> getAll() => _dataSource.fetchAll();

  Future<List<NamedRef>> getCompanies() => _dataSource.fetchCompanies();

  Future<List<NamedRef>> getCategories() => _dataSource.fetchCategories();

  Future<List<NamedRef>> getInventoryTypes() =>
      _dataSource.fetchInventoryTypes();

  /// Inserts a new item (when `model.id == null`) or updates an existing one.
  Future<StockItemModel> save(StockItemModel model) =>
      model.id == null ? _dataSource.insert(model) : _dataSource.update(model);

  Future<void> delete(int id) => _dataSource.delete(id);
}
