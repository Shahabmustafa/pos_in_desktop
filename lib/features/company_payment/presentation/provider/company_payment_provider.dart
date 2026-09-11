import 'package:flutter/foundation.dart';

import '../../../bank/data/model/bank_head_model.dart';
import '../../data/model/company_payable_ref.dart';
import '../../data/model/company_payment_model.dart';
import '../../data/repository/company_payment_repository.dart';

/// State/logic holder for the Company Payment feature.
class CompanyPaymentProvider extends ChangeNotifier {
  CompanyPaymentProvider([CompanyPaymentRepository? repository])
      : _repository = repository ?? CompanyPaymentRepository();

  final CompanyPaymentRepository _repository;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  List<CompanyPaymentModel> _items = const [];
  List<CompanyPaymentModel> get items => _items;

  List<CompanyPayableRef> _companies = const [];
  List<CompanyPayableRef> get companies => _companies;

  List<BankHeadModel> _banks = const [];
  List<BankHeadModel> get banks => _banks;

  double get totalPaid => _items.fold<double>(0, (a, p) => a + p.amount);

  /// Suggested next payment number, e.g. "SP-0004".
  String nextNumber() => 'SP-${(_items.length + 1).toString().padLeft(4, '0')}';

  /// What the business currently owes a company, refreshed after every save.
  double payableFor(int companyId) => _companies
      .firstWhere((c) => c.id == companyId,
          orElse: () => const CompanyPayableRef(id: -1, name: '', payable: 0))
      .payable;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.ensureSchema();
      final results = await Future.wait([
        _repository.getAll(),
        _repository.companies(),
        _repository.banks(),
      ]);
      _items = results[0] as List<CompanyPaymentModel>;
      _companies = results[1] as List<CompanyPayableRef>;
      _banks = results[2] as List<BankHeadModel>;
    } catch (e) {
      _error = _friendly(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<bool> save(CompanyPaymentModel model) async {
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
          'lib/features/company_payment/data/sql/company_payment.sql '
          'as a database superuser.';
    }
    if (t.contains('42P01')) {
      return 'The "company_payment" table does not exist yet. Run '
          'lib/features/company_payment/data/sql/company_payment.sql.';
    }
    return 'Something went wrong. Check the database connection.';
  }
}
