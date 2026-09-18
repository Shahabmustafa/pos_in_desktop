import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;

import '../../../purchase/data/repository/purchase_repository.dart';
import '../../../purchase_return/data/repository/purchase_return_repository.dart';
import '../../../reports/data/model/reports_model.dart' show LineReportRow;
import '../../../sale_invoice/data/repository/sale_invoice_repository.dart';
import '../../../sale_return/data/repository/sale_return_repository.dart';
import '../../data/model/party_ledger_model.dart';
import '../../data/repository/party_ledger_repository.dart';

/// Line items + totals behind one [LedgerEntry] — fetched on demand when a
/// row is opened, since the ledger itself only carries summary figures.
class LedgerEntryDetail {
  const LedgerEntryDetail({
    required this.items,
    required this.totals,
    this.rateHead = 'Rate',
  });

  final List<LineReportRow> items;

  /// Label/value pairs for the panel footer, last one bold (the grand total).
  final List<(String, double)> totals;
  final String rateHead;
}

/// State / logic holder for the Party Ledger screen. Holds the selected
/// [kind] (customer / company), the party list for that kind, the chosen
/// [party] and date [range], and the built [ledger].
class PartyLedgerProvider extends ChangeNotifier {
  PartyLedgerProvider([PartyLedgerRepository? repository])
      : _repository = repository ?? PartyLedgerRepository() {
    final now = DateTime.now();
    _range = DateTimeRange(
      start: DateTime(now.year, 1, 1),
      end: DateTime(now.year, now.month, now.day),
    );
  }

  final PartyLedgerRepository _repository;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  LedgerKind _kind = LedgerKind.customer;
  LedgerKind get kind => _kind;

  late DateTimeRange _range;
  DateTimeRange get range => _range;

  List<PartyRef> _parties = const [];
  List<PartyRef> get parties => _parties;

  PartyRef? _party;
  PartyRef? get party => _party;

  PartyLedger? _ledger;
  PartyLedger? get ledger => _ledger;

  LedgerEntry? _selected;
  LedgerEntry? get selected => _selected;

  LedgerEntryDetail? _detail;
  LedgerEntryDetail? get detail => _detail;

  bool _detailLoading = false;
  bool get detailLoading => _detailLoading;

  /// Loads the party list for the current [kind]; keeps the selected party if
  /// it is still in the list, then (re)builds the ledger. [preselectId] picks a
  /// party by id on first load (used when opened from a Customer / Company row).
  Future<void> load({int? preselectId}) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _parties = await _repository.parties(_kind);
      final wantId = preselectId ?? _party?.id;
      PartyRef? match;
      for (final p in _parties) {
        if (p.id == wantId) {
          match = p;
          break;
        }
      }
      _party = match ?? (_parties.length == 1 ? _parties.first : null);
      await _rebuild();
    } catch (e) {
      _error = _friendly(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> setKind(LedgerKind k) async {
    if (k == _kind) return;
    _kind = k;
    _party = null;
    _ledger = null;
    await load();
  }

  Future<void> selectParty(PartyRef? p) async {
    _party = p;
    _loading = true;
    notifyListeners();
    try {
      await _rebuild();
    } catch (e) {
      _error = _friendly(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> setRange(DateTimeRange r) async {
    _range = r;
    _loading = true;
    notifyListeners();
    try {
      await _rebuild();
    } catch (e) {
      _error = _friendly(e);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _rebuild() async {
    _selected = null;
    _detail = null;
    final p = _party;
    if (p == null) {
      _ledger = null;
      return;
    }
    _ledger = await _repository.ledger(_kind, p, _range.start, _range.end);
  }

  /// Opens (or closes, passing `null`) the detail panel for one ledger row.
  /// Fetches the source document's line items on demand — the ledger itself
  /// only carries summary figures.
  Future<void> selectEntry(LedgerEntry? e) async {
    _selected = e;
    _detail = null;
    if (e == null || !e.isPrimaryDocument) {
      notifyListeners();
      return;
    }
    _detailLoading = true;
    notifyListeners();
    try {
      _detail = await _fetchDetail(e);
    } catch (_) {
      _detail = null;
    } finally {
      _detailLoading = false;
      notifyListeners();
    }
  }

  Future<LedgerEntryDetail?> _fetchDetail(LedgerEntry e) async {
    switch (e.sourceType) {
      case LedgerSourceType.saleInvoice:
        final all = await SaleInvoiceRepository().getAll();
        final m = all.where((i) => i.id == e.sourceId);
        if (m.isEmpty) return null;
        final inv = m.first;
        return LedgerEntryDetail(
          items: [
            for (final it in inv.items)
              LineReportRow(
                product: it.productName,
                unit: it.unit,
                quantity: it.quantity,
                price: it.salePrice,
                discount: it.discountAmount,
                lineTotal: it.lineTotal,
              ),
          ],
          totals: [
            ('Sub Total', inv.subtotal),
            ('Discount', inv.discountTotal),
            if (inv.taxTotal != 0) ('Tax', inv.taxTotal),
            ('Total Amount', inv.grandTotal),
          ],
        );
      case LedgerSourceType.purchaseInvoice:
        final all = await PurchaseRepository().getAll();
        final m = all.where((i) => i.id == e.sourceId);
        if (m.isEmpty) return null;
        final inv = m.first;
        return LedgerEntryDetail(
          rateHead: 'Cost',
          items: [
            for (final it in inv.items)
              LineReportRow(
                product: it.productName,
                unit: it.unit,
                quantity: it.quantity,
                price: it.purchasePrice,
                discount: it.discountAmount,
                lineTotal: it.lineTotal,
              ),
          ],
          totals: [
            ('Sub Total', inv.subtotal),
            ('Discount', inv.discountTotal),
            if (inv.taxTotal != 0) ('Tax', inv.taxTotal),
            ('Total Amount', inv.grandTotal),
          ],
        );
      case LedgerSourceType.saleReturn:
        final all = await SaleReturnRepository().getAll();
        final m = all.where((r) => r.id == e.sourceId);
        if (m.isEmpty) return null;
        final ret = m.first;
        return LedgerEntryDetail(
          items: [
            for (final it in ret.items)
              LineReportRow(
                product: it.productName,
                unit: it.unit,
                quantity: it.quantity,
                price: it.salePrice,
                discount: it.discountAmount,
                lineTotal: it.lineTotal,
              ),
          ],
          totals: [('Return Value', ret.grandTotal)],
        );
      case LedgerSourceType.purchaseReturn:
        final all = await PurchaseReturnRepository().getAll();
        final m = all.where((r) => r.id == e.sourceId);
        if (m.isEmpty) return null;
        final ret = m.first;
        return LedgerEntryDetail(
          rateHead: 'Cost',
          items: [
            for (final it in ret.items)
              LineReportRow(
                product: it.productName,
                unit: '',
                quantity: it.quantity,
                price: it.unitPrice,
                discount: it.discountAmount,
                lineTotal: it.lineTotal,
              ),
          ],
          totals: [('Return Value', ret.grandTotal)],
        );
      case LedgerSourceType.customerPayment:
      case LedgerSourceType.companyPayment:
        return null;
    }
  }

  String _friendly(Object e) {
    final t = e.toString();
    if (t.contains('Database not connected')) {
      return 'Not connected to the database. Check the connection and retry.';
    }
    if (t.contains('42501')) return 'Permission denied reading the database.';
    return 'Could not build this ledger. Check the database connection.';
  }
}
