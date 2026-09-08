import 'package:flutter/foundation.dart';

import '../../data/model/voucher_model.dart';
import '../../data/repository/voucher_repository.dart';

/// State/logic holder for the Voucher feature.
class VoucherProvider extends ChangeNotifier {
  VoucherProvider([VoucherRepository? repository])
      : _repository = repository ?? VoucherRepository();

  final VoucherRepository _repository;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  List<VoucherModel> _items = const [];
  List<VoucherModel> get items => _items;

  /// `null` = all types.
  VoucherType? _filterType;
  VoucherType? get filterType => _filterType;

  double get totalPayments => _sum(VoucherType.payment);
  double get totalReceipts => _sum(VoucherType.receipt);
  double get netCash => totalReceipts - totalPayments;

  double _sum(VoucherType t) =>
      _items.where((v) => v.type == t).fold<double>(0, (a, v) => a + v.amount);

  /// Suggested next voucher number for [type], e.g. "PV-0004".
  String nextNumber(VoucherType type) {
    final prefix = switch (type) {
      VoucherType.payment => 'PV',
      VoucherType.receipt => 'RV',
      VoucherType.journal => 'JV',
    };
    final count = _items.where((v) => v.type == type).length + 1;
    return '$prefix-${count.toString().padLeft(4, '0')}';
  }

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.ensureSchema();
      _items = await _repository.getAll(type: _filterType);
    } catch (e) {
      _error = _friendly(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> filterByType(VoucherType? type) async {
    _filterType = type;
    _items = await _repository.getAll(type: type);
    notifyListeners();
  }

  Future<bool> save(VoucherModel model) async {
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
      _items = _items.where((v) => v.id != id).toList();
      notifyListeners();
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
      return 'Permission denied. Run lib/features/voucher/data/sql/voucher.sql '
          'as a database superuser.';
    }
    if (t.contains('42P01')) {
      return 'The "voucher" table does not exist yet. Run '
          'lib/features/voucher/data/sql/voucher.sql.';
    }
    return 'Something went wrong. Check the database connection.';
  }
}
