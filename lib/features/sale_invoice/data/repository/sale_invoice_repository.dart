import '../../../bank/data/model/bank_head_model.dart';
import '../datasource/held_sale_invoice_datasource.dart';
import '../datasource/sale_invoice_datasource.dart';
import '../model/held_sale_invoice_model.dart';
import '../model/sale_invoice_model.dart';
import '../model/sale_invoice_refs.dart';

/// Repository for the Sale Invoice feature. Presentation layer depends on this.
class SaleInvoiceRepository {
  SaleInvoiceRepository([
    SaleInvoiceDataSource? dataSource,
    HeldSaleInvoiceDataSource? heldDataSource,
  ])  : _dataSource = dataSource ?? const SaleInvoiceDataSource(),
        _heldDataSource = heldDataSource ?? const HeldSaleInvoiceDataSource();

  final SaleInvoiceDataSource _dataSource;
  final HeldSaleInvoiceDataSource _heldDataSource;

  Future<void> ensureSchema() => _dataSource.ensureSchema();

  Future<List<SaleInvoiceModel>> getAll() => _dataSource.fetchAll();

  Future<List<CustomerRef>> getCustomers() => _dataSource.fetchCustomers();

  Future<List<ProductRef>> getProducts() => _dataSource.fetchProducts();

  Future<List<BankHeadModel>> getBanks() => _dataSource.fetchBanks();

  /// Inserts a new invoice (when `model.id == null`) or updates an existing one.
  Future<SaleInvoiceModel> save(SaleInvoiceModel model) => model.id == null
      ? _dataSource.insert(model)
      : _dataSource.update(model);

  Future<void> delete(int id) => _dataSource.delete(id);

  // ── Held (parked) invoices ─────────────────────────────────────────
  Future<List<HeldSaleInvoiceModel>> getHeld() => _heldDataSource.fetchAll();

  Future<HeldSaleInvoiceModel> hold(HeldSaleInvoiceModel held) =>
      _heldDataSource.insert(held);

  Future<void> deleteHeld(int id) => _heldDataSource.delete(id);
}
