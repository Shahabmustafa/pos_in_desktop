import 'package:flutter/foundation.dart';

import '../../data/model/bank_entry_model.dart';
import '../../data/model/bank_head_model.dart';
import '../../data/repository/bank_repository.dart';

/// State/logic holder for the Bank feature (heads + entries).
class BankProvider extends ChangeNotifier {
  BankProvider([BankRepository? repository])
      : _repository = repository ?? BankRepository();

  final BankRepository _repository;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  List<BankHeadModel> _heads = const [];
  List<BankHeadModel> get heads => _heads;

  Map<int, double> _balances = const {};
  double balanceOf(int headId) => _balances[headId] ?? 0;
  double get totalBalance =>
      _balances.values.fold<double>(0, (a, b) => a + b);

  List<BankEntryModel> _entries = const [];
  List<BankEntryModel> get entries => _entries;

  /// `null` = all heads.
  int? _entryFilterHeadId;
  int? get entryFilterHeadId => _entryFilterHeadId;

  String headTitle(int id) =>
      _heads.firstWhere((h) => h.id == id,
              orElse: () => const BankHeadModel(title: '—'))
          .title;

  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.ensureSchema();
      _heads = await _repository.getHeads();
      _balances = await _repository.getHeadBalances();
      _entries =
          await _repository.getEntries(headId: _entryFilterHeadId);
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

  Future<bool> saveHead(BankHeadModel h) => _run(() => _repository.saveHead(h));
  Future<bool> deleteHead(int id) => _run(() => _repository.deleteHead(id));
  Future<bool> saveEntry(BankEntryModel e) =>
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
      return 'Permission denied. Run lib/features/bank/data/sql/bank.sql as a '
          'database superuser.';
    }
    if (t.contains('42P01')) {
      return 'Bank tables do not exist yet. Run lib/features/bank/data/sql/bank.sql.';
    }
    return 'Something went wrong. Check the database connection.';
  }
}
