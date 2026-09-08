import '../datasource/bank_datasource.dart';
import '../model/bank_entry_model.dart';
import '../model/bank_head_model.dart';

/// Repository for the Bank feature. Presentation layer depends on this.
class BankRepository {
  BankRepository([BankDataSource? dataSource])
      : _dataSource = dataSource ?? const BankDataSource();

  final BankDataSource _dataSource;

  Future<void> ensureSchema() => _dataSource.ensureSchema();

  // Heads
  Future<List<BankHeadModel>> getHeads() => _dataSource.fetchHeads();
  Future<Map<int, double>> getHeadBalances() => _dataSource.headBalances();
  Future<BankHeadModel> saveHead(BankHeadModel h) =>
      h.id == null ? _dataSource.insertHead(h) : _dataSource.updateHead(h);
  Future<void> deleteHead(int id) => _dataSource.deleteHead(id);

  // Entries
  Future<List<BankEntryModel>> getEntries({int? headId}) =>
      _dataSource.fetchEntries(headId: headId);
  Future<void> saveEntry(BankEntryModel e) =>
      e.id == null ? _dataSource.insertEntry(e) : _dataSource.updateEntry(e);
  Future<void> deleteEntry(int id) => _dataSource.deleteEntry(id);
}
