import 'package:flutter/foundation.dart';

import '../../../bank/data/model/bank_head_model.dart';
import '../../../customer/data/datasource/customer_datasource.dart'
    show kWalkInCustomerName;
import '../../data/datasource/sale_invoice_datasource.dart'
    show InsufficientStockException;
import '../../data/model/held_sale_invoice_model.dart';
import '../../data/model/sale_invoice_model.dart';
import '../../data/model/sale_invoice_refs.dart';
import '../../data/repository/sale_invoice_repository.dart';

/// State/logic holder for the Sale Invoice feature.
class SaleInvoiceProvider extends ChangeNotifier {
  SaleInvoiceProvider([SaleInvoiceRepository? repository])
      : _repository = repository ?? SaleInvoiceRepository();

  final SaleInvoiceRepository _repository;

  bool _bootstrapped = false;

  bool _loading = false;
  bool get loading => _loading;

  bool _saving = false;
  bool get saving => _saving;

  String? _error;
  String? get error => _error;

  List<SaleInvoiceModel> _items = const [];
  List<SaleInvoiceModel> get items => _items;

  SaleInvoiceModel? _lastSaved;

  /// The invoice from the most recent successful [save] (with its DB id and
  /// invoice number), for printing a receipt.
  SaleInvoiceModel? get lastSaved => _lastSaved;

  List<CustomerRef> _customers = const [];

  /// Customers for the invoice's customer picker (from the Customer feature).
  List<CustomerRef> get customers => _customers;

  /// The default walk-in customer, if the row exists.
  CustomerRef? get walkInCustomer {
    for (final c in _customers) {
      if (c.name.trim().toLowerCase() == kWalkInCustomerName.toLowerCase()) {
        return c;
      }
    }
    return null;
  }

  List<ProductRef> _products = const [];

  /// Products for the invoice line picker (from the Stock Inventory feature).
  List<ProductRef> get products => _products;

  List<BankHeadModel> _banks = const [];

  /// Active bank accounts for the optional "Bank" picker (from the Bank feature).
  List<BankHeadModel> get banks => _banks;

  List<HeldSaleInvoiceModel> _held = const [];

  /// Parked carts waiting to be resumed on the Sale Invoice screen.
  List<HeldSaleInvoiceModel> get heldInvoices => _held;

  int get invoiceCount => _items.length;

  double get totalSales => _items.fold<double>(0, (a, p) => a + p.grandTotal);

  /// Suggested next invoice number, e.g. "SI-0004".
  String nextNumber() => 'SI-${(_items.length + 1).toString().padLeft(4, '0')}';

  Future<void> load() async {
    if (!_bootstrapped) {
      _loading = true;
      notifyListeners();
    }
    _error = null;
    try {
      await _repository.ensureSchema();
      _customers = await _repository.getCustomers();
      _products = await _repository.getProducts();
      _banks = await _repository.getBanks();
      _items = await _repository.getAll();
      _bootstrapped = true;
      // Held invoices are a convenience — a failure here must not break the
      // screen.
      try {
        _held = await _repository.getHeld();
      } catch (_) {
        _held = const [];
      }
    } catch (e) {
      _error = _friendly(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> save(SaleInvoiceModel model) async {
    _saving = true;
    notifyListeners();
    try {
      _lastSaved = await _repository.save(model);
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

  /// Parks the current cart as a held invoice. Returns `true` on success.
  Future<bool> hold(HeldSaleInvoiceModel held) async {
    try {
      await _repository.hold(held);
      _held = await _repository.getHeld();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendly(e);
      notifyListeners();
      return false;
    }
  }

  /// Removes a held invoice (after it is resumed into the cart, or discarded).
  Future<void> deleteHeld(int id) async {
    _held = _held.where((h) => h.id != id).toList();
    notifyListeners();
    try {
      await _repository.deleteHeld(id);
    } catch (e) {
      _error = _friendly(e);
      notifyListeners();
    }
  }

  Future<bool> delete(int id) async {
    try {
      await _repository.delete(id);
      _items = _items.where((p) => p.id != id).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = _friendly(e);
      notifyListeners();
      return false;
    }
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
