import '../../../bank/data/model/bank_head_model.dart';
import '../../../sale_invoice/data/model/sale_invoice_refs.dart';
import '../datasource/customer_payment_datasource.dart';
import '../model/customer_payment_model.dart';

/// Repository for the Customer Payment feature. Presentation layer depends
/// on this, not the datasource directly.
class CustomerPaymentRepository {
  CustomerPaymentRepository([CustomerPaymentDataSource? dataSource])
      : _dataSource = dataSource ?? const CustomerPaymentDataSource();

  final CustomerPaymentDataSource _dataSource;

  Future<void> ensureSchema() => _dataSource.ensureSchema();

  Future<List<CustomerPaymentModel>> getAll() => _dataSource.fetchAll();

  Future<List<CustomerRef>> customers() => _dataSource.fetchCustomers();

  Future<List<BankHeadModel>> banks() => _dataSource.fetchBanks();

  /// Inserts a new payment (when `model.id == null`) or updates an existing one.
  Future<CustomerPaymentModel> save(CustomerPaymentModel model) =>
      model.id == null ? _dataSource.insert(model) : _dataSource.update(model);

  Future<void> delete(int id) => _dataSource.delete(id);
}
