import 'package:flutter/foundation.dart';

import '../../../sale_invoice/data/datasource/sale_invoice_datasource.dart'
    show InsufficientStockException;
import '../../../sale_invoice/data/model/sale_invoice_model.dart';
import '../../../sale_invoice/data/model/sale_invoice_refs.dart';
import '../../data/repository/sale_exchange_repository.dart';

/// State/logic holder for the Sale Exchange feature.
///
/// Pick a sale invoice, drop the lines being returned and add the new ones;
/// [applyExchange] writes the changed invoice back (stock + customer balance
/// follow automatically).
class SaleExchangeProvider extends ChangeNotifier {
  SaleExchangeProvider([SaleExchangeRepository? repository])
      : _repository = repository ?? SaleExchangeRepository();

  final SaleExchangeRepository _repository;

  bool _bootstrapped = false;

  bool _loading = false;
  bool get loading => _loading;

  bool _saving = false;
  bool get saving => _saving;

  String? _error;
  String? get error => _error;

  List<SaleInvoiceModel> _invoices = const [];
  List<SaleInvoiceModel> get invoices => _invoices;

  List<ProductRef> _products = const [];
  List<ProductRef> get products => _products;

  int get invoiceCount => _invoices.length;

  SaleInvoiceModel? _selected;
  SaleInvoiceModel? get selected => _selected;

  void select(SaleInvoiceModel invoice) {
    _selected = invoice;
    notifyListeners();
  }

  void clearSelection() {
    _selected = null;
    notifyListeners();
  }

  Future<void> load() async {
    if (!_bootstrapped) {
      _loading = true;
      notifyListeners();
    }
    _error = null;
    try {
      await _repository.ensureSchema();
      _products = await _repository.getProducts();
      _invoices = await _repository.getSaleInvoices();
      final keepId = _selected?.id;
      SaleInvoiceModel? stillOpen;
      if (keepId != null) {
        for (final i in _invoices) {
          if (i.id == keepId) {
            stillOpen = i;
            break;
          }
        }
      }
      _selected = stillOpen;
      _bootstrapped = true;
    } catch (e) {
      _error = _friendly(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Replaces [invoice]'s lines with [finalItems] (the exchange cart) and saves.
  /// Products that left the cart are logged as returned, new ones as added.
  /// Returns true on success.
  Future<bool> applyExchange(
    SaleInvoiceModel invoice,
    List<SaleInvoiceItemModel> finalItems,
  ) async {
    if (finalItems.isEmpty) {
      _error = 'An invoice must keep at least one item.';
      notifyListeners();
      return false;
    }
    if (!_changed(invoice.items, finalItems)) {
      _error = 'Nothing changed on this invoice.';
      notifyListeners();
      return false;
    }

    final finalPids = {for (final i in finalItems) i.productId};
    final origPids = {for (final i in invoice.items) i.productId};
    final removed = [
      for (final it in invoice.items)
        if (!finalPids.contains(it.productId)) it,
    ];
    final added = [
      for (final it in finalItems)
        if (!origPids.contains(it.productId)) it,
    ];

    _saving = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.exchange(
        original: invoice,
        updated: invoice.copyWith(items: finalItems),
        removed: removed,
        added: added,
      );
      await load();
      return true;
    } catch (e) {
      _error = _friendly(e);
      return false;
    } finally {
      _saving = false;
      notifyListeners();
    }
  }

  bool _changed(
      List<SaleInvoiceItemModel> a, List<SaleInvoiceItemModel> b) {
    if (a.length != b.length) return true;
    String key(SaleInvoiceItemModel i) => '${i.productId}|${i.quantity}|'
        '${i.salePrice}|${i.discount}|${i.discountFlat}|${i.tax}';
    final ka = a.map(key).toList()..sort();
    final kb = b.map(key).toList()..sort();
    for (var i = 0; i < ka.length; i++) {
      if (ka[i] != kb[i]) return true;
    }
    return false;
  }

  String _friendly(Object e) {
    if (e is InsufficientStockException) return e.message;
    final t = e.toString();
    if (t.contains('42501')) {
      return 'Permission denied. Run '
          'lib/features/sale_invoice/data/sql/sale_invoice.sql as a database '
          'superuser.';
    }
    if (t.contains('42P01')) {
      return 'The "sale_invoice" tables do not exist yet. Run '
          'lib/features/sale_invoice/data/sql/sale_invoice.sql.';
    }
    return 'Something went wrong. Check the database connection.';
  }
}
