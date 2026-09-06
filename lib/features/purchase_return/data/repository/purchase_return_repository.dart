import '../../../purchase/data/model/purchase_model.dart';
import '../datasource/purchase_return_datasource.dart';
import '../model/purchase_return_model.dart';

/// Repository for the Purchase Return feature. Presentation layer depends on this.
class PurchaseReturnRepository {
  PurchaseReturnRepository([PurchaseReturnDataSource? dataSource])
      : _dataSource = dataSource ?? const PurchaseReturnDataSource();

  final PurchaseReturnDataSource _dataSource;

  Future<void> ensureSchema() => _dataSource.ensureSchema();

  /// Purchase invoices the user picks from to build a return.
  Future<List<PurchaseModel>> getPurchaseInvoices() =>
      _dataSource.fetchPurchaseInvoices();

  /// Existing purchase returns (for Reports).
  Future<List<PurchaseReturnModel>> getAll() => _dataSource.fetchAll();

  /// Sends the picked [selections] back off [invoice].
  Future<void> returnFromInvoice({
    required PurchaseModel invoice,
    required List<PurchaseReturnSelection> selections,
  }) =>
      _dataSource.returnFromInvoice(invoice: invoice, selections: selections);

  Future<void> delete(int id) => _dataSource.delete(id);
}
