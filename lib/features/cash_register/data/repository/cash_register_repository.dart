import '../datasource/cash_register_datasource.dart';
import '../model/cash_register_model.dart';

/// Repository for the Cash Register feature.
class CashRegisterRepository {
  CashRegisterRepository([CashRegisterDataSource? dataSource])
      : _dataSource = dataSource ?? const CashRegisterDataSource();

  final CashRegisterDataSource _dataSource;

  Future<void> ensureSchema() => _dataSource.ensureSchema();

  Future<CashAccount> account() => _dataSource.account();
  Future<CashAccount> saveAccount(CashAccount a) => _dataSource.saveAccount(a);

  Future<CashBook> cashBook(DateTime from, DateTime to) =>
      _dataSource.cashBook(from, to);

  Future<void> saveEntry(CashEntry e) => e.id == null
      ? _dataSource.insertEntry(e).then((_) {})
      : _dataSource.updateEntry(e).then((_) {});

  Future<void> deleteEntry(int id) => _dataSource.deleteEntry(id);
}
