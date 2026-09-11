import 'package:flutter/foundation.dart';

import '../../../bank/data/model/bank_head_model.dart';
import '../../../sale_invoice/data/model/sale_invoice_refs.dart';
import '../../data/model/customer_payment_model.dart';
import '../../data/repository/customer_payment_repository.dart';

/// State/logic holder for the Customer Payment feature.
class CustomerPaymentProvider extends ChangeNotifier {
  CustomerPaymentProvider([CustomerPaymentRepository? repository])
      : _repository = repository ?? CustomerPaymentRepository();

  final CustomerPaymentRepository _repository;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  List<CustomerPaymentModel> _items = const [];
  List<CustomerPaymentModel> get items => _items;

  List<CustomerRef> _customers = const [];
  List<CustomerRef> get customers => _customers;

  List<BankHeadModel> _banks = const [];
  List<BankHeadModel> get banks => _banks;

  double get totalCollected => _items.fold<double>(0, (a, p) => a + p.amount);

  /// Suggested next payment number, e.g. "CP-0004".
  String nextNumber() => 'CP-${(_items.length + 1).toString().padLeft(4, '0')}';

  /// Current outstanding balance for a customer, refreshed after every save.
  double dueFor(int customerId) => _customers
      .firstWhere((c) => c.id == customerId,
          orElse: () => const CustomerRef(id: -1, name: ''))
      .openingBalance;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.ensureSchema();
      final results = await Future.wait([
        _repository.getAll(),
        _repository.customers(),
        _repository.banks(),
      ]);
      _items = results[0] as List<CustomerPaymentModel>;
      _customers = results[1] as List<CustomerRef>;
      _banks = results[2] as List<BankHeadModel>;
    } catch (e) {
      _error = _friendly(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> save(CustomerPaymentModel model) async {
    try {
      await _repository.save(model);
      await load();
      return true;
    } catch (e) {
      _error = _friendly(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> delete(int id) async {
    try {
      await _repository.delete(id);
      await load();
      return true;
    } catch (e) {
      _error = _friendly(e);
      notifyListeners();
      return false;
    }
  }

  String _friendly(Object e) {
    final t = e.toString();
    if (t.contains('42501')) {
      return 'Permission denied. Run '
          'lib/features/customer_payment/data/sql/customer_payment.sql '
          'as a database superuser.';
    }
    if (t.contains('42P01')) {
      return 'The "customer_payment" table does not exist yet. Run '
          'lib/features/customer_payment/data/sql/customer_payment.sql.';
    }
    return 'Something went wrong. Check the database connection.';
  }
}
