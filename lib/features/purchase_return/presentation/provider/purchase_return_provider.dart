import 'package:flutter/foundation.dart';

import '../../../purchase/data/model/purchase_model.dart';
import '../../data/datasource/purchase_return_datasource.dart';
import '../../data/repository/purchase_return_repository.dart';

/// State/logic holder for the Purchase Return feature.
///
/// The screen lists purchase invoices; picking one and confirming a return
/// either deletes the invoice (full return) or shrinks it (partial), and
/// records a `purchase_return` behind the scenes.
class PurchaseReturnProvider extends ChangeNotifier {
  PurchaseReturnProvider([PurchaseReturnRepository? repository])
      : _repository = repository ?? PurchaseReturnRepository();

  final PurchaseReturnRepository _repository;

  bool _bootstrapped = false;

  bool _loading = false;
  bool get loading => _loading;

  bool _saving = false;
  bool get saving => _saving;

  String? _error;
  String? get error => _error;

  List<PurchaseModel> _invoices = const [];
  List<PurchaseModel> get invoices => _invoices;

  int get invoiceCount => _invoices.length;
  double get invoicedTotal =>
      _invoices.fold<double>(0, (a, i) => a + i.grandTotal);

  PurchaseModel? _selected;
  PurchaseModel? get selected => _selected;

  void select(PurchaseModel invoice) {
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
      _invoices = await _repository.getPurchaseInvoices();
      final keepId = _selected?.id;
      PurchaseModel? stillOpen;
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
    PurchaseModel invoice,
    List<PurchaseReturnSelection> selections,
  ) async {
    if (selections.isEmpty) return false;
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.returnFromInvoice(
        invoice: invoice,
        selections: selections,
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
    final t = e.toString();
    if (t.contains('42501')) {
      return 'Permission denied. Run '
          'lib/features/purchase_return/data/sql/purchase_return.sql as a '
          'database superuser.';
    }
    if (t.contains('42P01')) {
      return 'The purchase-return tables do not exist yet. Run '
          'lib/features/purchase_return/data/sql/purchase_return.sql.';
    }
    return 'Something went wrong. Check the database connection.';
  }
}
