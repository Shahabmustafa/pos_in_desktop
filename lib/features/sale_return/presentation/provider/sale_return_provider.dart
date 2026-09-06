import 'package:flutter/foundation.dart';

import '../../../bank/data/model/bank_head_model.dart';
import '../../../sale_invoice/data/datasource/sale_invoice_datasource.dart'
    show InsufficientStockException;
import '../../../sale_invoice/data/model/sale_invoice_model.dart';
import '../../data/datasource/sale_return_datasource.dart';
import '../../data/repository/sale_return_repository.dart';

/// State/logic holder for the Sale Return feature.
///
/// The screen lists sale invoices; picking one and confirming a return either
/// deletes the invoice (full return) or shrinks it (partial), and records a
/// `sale_return` behind the scenes.
class SaleReturnProvider extends ChangeNotifier {
  SaleReturnProvider([SaleReturnRepository? repository])
      : _repository = repository ?? SaleReturnRepository();

  final SaleReturnRepository _repository;

  bool _bootstrapped = false;

  bool _loading = false;
  bool get loading => _loading;

  bool _saving = false;
  bool get saving => _saving;

  String? _error;
  String? get error => _error;

  List<SaleInvoiceModel> _invoices = const [];
  List<SaleInvoiceModel> get invoices => _invoices;

  List<BankHeadModel> _banks = const [];

  /// Active bank accounts for the optional "Bank" picker on the return panel.
  List<BankHeadModel> get banks => _banks;

  int get invoiceCount => _invoices.length;
  double get invoicedTotal =>
      _invoices.fold<double>(0, (a, i) => a + i.grandTotal);

  /// The invoice whose detail panel is open, if any.
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
      _banks = await _repository.getBanks();
      _invoices = await _repository.getSaleInvoices();
      // Keep the open panel pointing at the fresh copy (or close it if the
      // invoice is gone after a full return).
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

  /// Returns [selections] off [invoice]. Returns true on success.
  Future<bool> submitReturn(
    SaleInvoiceModel invoice,
    List<ReturnSelection> selections, {
    int? bankHeadId,
  }) async {
    if (selections.isEmpty) return false;
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.returnFromInvoice(
        invoice: invoice,
        selections: selections,
        bankHeadId: bankHeadId,
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

  String _friendly(Object e) {
    if (e is InsufficientStockException) return e.message;
    final t = e.toString();
    if (t.contains('42501')) {
      return 'Permission denied. Run '
          'lib/features/sale_return/data/sql/sale_return.sql as a database '
          'superuser.';
    }
    if (t.contains('42P01')) {
      return 'The "sale_return" tables do not exist yet. Run '
          'lib/features/sale_return/data/sql/sale_return.sql.';
    }
    return 'Something went wrong. Check the database connection.';
  }
}
