import 'package:flutter/foundation.dart';

import '../../data/model/expense_entry_model.dart';
import '../../data/model/expense_head_model.dart';
import '../../data/repository/expense_repository.dart';

/// State/logic holder for the Expense feature (heads + entries).
class ExpenseProvider extends ChangeNotifier {
  ExpenseProvider([ExpenseRepository? repository])
      : _repository = repository ?? ExpenseRepository();

  final ExpenseRepository _repository;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  List<ExpenseHeadModel> _heads = const [];
  List<ExpenseHeadModel> get heads => _heads;

  Map<int, double> _totals = const {};
  double totalOf(int headId) => _totals[headId] ?? 0;
  double get grandTotal => _totals.values.fold<double>(0, (a, b) => a + b);

  List<ExpenseEntryModel> _entries = const [];
  List<ExpenseEntryModel> get entries => _entries;

  double get entriesTotal =>
      _entries.fold<double>(0, (a, e) => a + e.amount);

  /// `null` = all heads.
  int? _entryFilterHeadId;
  int? get entryFilterHeadId => _entryFilterHeadId;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.ensureSchema();
      _heads = await _repository.getHeads();
      _totals = await _repository.getHeadTotals();
      _entries = await _repository.getEntries(headId: _entryFilterHeadId);
    } catch (e) {
      _error = _friendly(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> filterEntriesByHead(int? headId) async {
    _entryFilterHeadId = headId;
    _entries = await _repository.getEntries(headId: headId);
    notifyListeners();
  }

  Future<bool> saveHead(ExpenseHeadModel h) =>
      _run(() => _repository.saveHead(h));
  Future<bool> deleteHead(int id) => _run(() => _repository.deleteHead(id));
  Future<bool> saveEntry(ExpenseEntryModel e) =>
      _run(() => _repository.saveEntry(e));
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
    if (t.contains('42501')) {
      return 'Permission denied. Run lib/features/expense/data/sql/expense.sql '
          'as a database superuser.';
    }
    if (t.contains('42P01')) {
      return 'Expense tables do not exist yet. Run '
          'lib/features/expense/data/sql/expense.sql.';
    }
    return 'Something went wrong. Check the database connection.';
  }
}
