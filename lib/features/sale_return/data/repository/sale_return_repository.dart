import '../../../bank/data/model/bank_head_model.dart';
import '../../../sale_invoice/data/model/sale_invoice_model.dart';
import '../datasource/sale_return_datasource.dart';
import '../model/sale_return_model.dart';
import '../model/sale_return_refs.dart';

/// Repository for the Sale Return feature. Presentation layer depends on this.
class SaleReturnRepository {
  SaleReturnRepository([SaleReturnDataSource? dataSource])
      : _dataSource = dataSource ?? const SaleReturnDataSource();

  final SaleReturnDataSource _dataSource;

  Future<void> ensureSchema() => _dataSource.ensureSchema();

  /// Sale invoices the user picks from to build a return.
  Future<List<SaleInvoiceModel>> getSaleInvoices() =>
      _dataSource.fetchSaleInvoices();

  /// Existing sale returns (for Reports).
  Future<List<SaleReturnModel>> getAll() => _dataSource.fetchAll();

  Future<List<CustomerRef>> getCustomers() => _dataSource.fetchCustomers();

  Future<List<ProductRef>> getProducts() => _dataSource.fetchProducts();

  Future<List<BankHeadModel>> getBanks() => _dataSource.fetchBanks();

  /// Returns the picked [selections] off [invoice]. See
  /// [SaleReturnDataSource.returnFromInvoice].
  Future<void> returnFromInvoice({
    required SaleInvoiceModel invoice,
    required List<ReturnSelection> selections,
    int? bankHeadId,
  }) =>
      _dataSource.returnFromInvoice(
        invoice: invoice,
        selections: selections,
        bankHeadId: bankHeadId,
      );

  Future<void> delete(int id) => _dataSource.delete(id);
}
