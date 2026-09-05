import '../datasource/customer_datasource.dart';
import '../model/customer_model.dart';

/// Repository for the Customer feature. Presentation layer depends on this.
class CustomerRepository {
  CustomerRepository([CustomerDataSource? dataSource])
      : _dataSource = dataSource ?? const CustomerDataSource();

  final CustomerDataSource _dataSource;

  Future<void> ensureSchema() => _dataSource.ensureSchema();

  Future<List<CustomerModel>> getAll() => _dataSource.fetchAll();

  /// Inserts a new customer (when `model.id == null`) or updates an existing one.
  Future<CustomerModel> save(CustomerModel model) =>
      model.id == null ? _dataSource.insert(model) : _dataSource.update(model);

  Future<void> delete(int id) => _dataSource.delete(id);
}
