import '../../../sale_invoice/data/model/sale_invoice_model.dart';
import '../../../sale_invoice/data/model/sale_invoice_refs.dart';
import '../datasource/sale_exchange_datasource.dart';
import '../model/sale_exchange_model.dart';

/// Repository for the Sale Exchange feature. Presentation layer depends on this.
class SaleExchangeRepository {
  SaleExchangeRepository([SaleExchangeDataSource? dataSource])
      : _dataSource = dataSource ?? const SaleExchangeDataSource();

  final SaleExchangeDataSource _dataSource;

  Future<void> ensureSchema() => _dataSource.ensureSchema();

  Future<List<SaleInvoiceModel>> getSaleInvoices() =>
      _dataSource.fetchSaleInvoices();

  Future<List<ProductRef>> getProducts() => _dataSource.fetchProducts();

  /// Recorded exchanges (for Reports).
  Future<List<SaleExchangeRecord>> getAll() => _dataSource.fetchAll();

  Future<void> exchange({
    required SaleInvoiceModel original,
    required SaleInvoiceModel updated,
    required List<SaleInvoiceItemModel> removed,
    required List<SaleInvoiceItemModel> added,
  }) =>
      _dataSource.applyExchange(
        original: original,
        updated: updated,
        removed: removed,
        added: added,
      );
}
