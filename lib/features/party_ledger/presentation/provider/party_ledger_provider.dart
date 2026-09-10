import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show DateTimeRange;

import '../../data/model/party_ledger_model.dart';
import '../../data/repository/party_ledger_repository.dart';

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
    final p = _party;
    if (p == null) {
      _ledger = null;
      return;
    }
    _ledger = await _repository.ledger(_kind, p, _range.start, _range.end);
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
