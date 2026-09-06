import '../datasource/purchase_datasource.dart';
import '../model/purchase_model.dart';
import '../model/purchase_refs.dart';

/// Repository for the Purchase Invoice feature. Presentation layer depends on
/// this.
class PurchaseRepository {
  PurchaseRepository([PurchaseDataSource? dataSource])
      : _dataSource = dataSource ?? const PurchaseDataSource();

  final PurchaseDataSource _dataSource;

  Future<void> ensureSchema() => _dataSource.ensureSchema();

  Future<List<PurchaseModel>> getAll() => _dataSource.fetchAll();

  Future<List<CompanyRef>> getCompanies() => _dataSource.fetchCompanies();

  Future<List<ProductRef>> getProducts() => _dataSource.fetchProducts();

  /// Inserts a new invoice (when `model.id == null`) or updates an existing one.
  Future<PurchaseModel> save(PurchaseModel model) => model.id == null
      ? _dataSource.insert(model)
      : _dataSource.update(model);

  Future<void> delete(int id) => _dataSource.delete(id);
}
