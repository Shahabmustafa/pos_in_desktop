import '../datasource/expense_datasource.dart';
import '../model/expense_entry_model.dart';
import '../model/expense_head_model.dart';

/// Repository for the Expense feature. Presentation layer depends on this.
class ExpenseRepository {
  ExpenseRepository([ExpenseDataSource? dataSource])
      : _dataSource = dataSource ?? const ExpenseDataSource();

  final ExpenseDataSource _dataSource;

  Future<void> ensureSchema() => _dataSource.ensureSchema();

  // Heads
  Future<List<ExpenseHeadModel>> getHeads() => _dataSource.fetchHeads();
  Future<Map<int, double>> getHeadTotals() => _dataSource.headTotals();
  Future<ExpenseHeadModel> saveHead(ExpenseHeadModel h) =>
      h.id == null ? _dataSource.insertHead(h) : _dataSource.updateHead(h);
  Future<void> deleteHead(int id) => _dataSource.deleteHead(id);

  // Entries
  Future<List<ExpenseEntryModel>> getEntries({int? headId}) =>
      _dataSource.fetchEntries(headId: headId);
  Future<void> saveEntry(ExpenseEntryModel e) =>
      e.id == null ? _dataSource.insertEntry(e) : _dataSource.updateEntry(e);
  Future<void> deleteEntry(int id) => _dataSource.deleteEntry(id);
}
