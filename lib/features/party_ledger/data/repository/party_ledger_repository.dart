import '../datasource/party_ledger_datasource.dart';
import '../model/party_ledger_model.dart';

/// Repository for the Party Ledger feature. The presentation layer depends on
/// this, not on the datasource.
class PartyLedgerRepository {
  PartyLedgerRepository([PartyLedgerDataSource? dataSource])
      : _dataSource = dataSource ?? const PartyLedgerDataSource();

  final PartyLedgerDataSource _dataSource;

  Future<List<PartyRef>> parties(LedgerKind kind) => switch (kind) {
        LedgerKind.customer => _dataSource.customers(),
        LedgerKind.company => _dataSource.companies(),
      };

  Future<PartyLedger> ledger(
    LedgerKind kind,
    PartyRef party,
    DateTime from,
    DateTime to,
  ) =>
      switch (kind) {
        LedgerKind.customer => _dataSource.customerLedger(party, from, to),
        LedgerKind.company => _dataSource.companyLedger(party, from, to),
      };
}
