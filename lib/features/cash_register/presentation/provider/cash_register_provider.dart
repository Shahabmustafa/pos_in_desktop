import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;

import '../../data/model/cash_register_model.dart';
import '../../data/repository/cash_register_repository.dart';

/// State / logic holder for the Cash Register screen.
class CashRegisterProvider extends ChangeNotifier {
  CashRegisterProvider([CashRegisterRepository? repository])
      : _repository = repository ?? CashRegisterRepository() {
    final now = DateTime.now();
    _range = DateTimeRange(
      start: DateTime(now.year, now.month, 1),
      end: DateTime(now.year, now.month, now.day),
    );
  }

  final CashRegisterRepository _repository;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  late DateTimeRange _range;
  DateTimeRange get range => _range;

  CashAccount _account = CashAccount();
  CashAccount get account => _account;

  CashBook _book = CashBook.empty;
  CashBook get book => _book;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.ensureSchema();
      _account = await _repository.account();
      _book = await _repository.cashBook(_range.start, _range.end);
    } catch (e) {
      _error = _friendly(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> setRange(DateTimeRange r) async {
    _range = r;
    await load();
  }

  Future<bool> saveAccount(CashAccount a) =>
      _run(() => _repository.saveAccount(a));
  Future<bool> saveEntry(CashEntry e) => _run(() => _repository.saveEntry(e));
  Future<bool> deleteEntry(int id) => _run(() => _repository.deleteEntry(id));

  Future<bool> _run(Future<void> Function() action) async {
    try {
      await action();
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
    if (t.contains('Database not connected')) {
      return 'Not connected to the database. Check the connection and retry.';
    }
    if (t.contains('42501')) return 'Permission denied reading the database.';
    return 'Something went wrong. Check the database connection.';
  }
}
