import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos/features/party_ledger/data/model/party_ledger_model.dart';
import 'package:pos/features/party_ledger/data/repository/party_ledger_repository.dart';
import 'package:pos/features/party_ledger/presentation/provider/party_ledger_provider.dart';
import 'package:pos/features/party_ledger/presentation/screen/party_ledger_screen.dart';

LedgerEntry _e(
  String date,
  String type, {
  double debit = 0,
  double credit = 0,
  int sortKey = 0,
  String doc = 'D',
}) =>
    LedgerEntry(
      date: DateTime.parse(date),
      type: type,
      docNo: doc,
      detail: '',
      debit: debit,
      credit: credit,
      sortKey: sortKey,
    );

/// Repository that serves fixed data without a database.
class _FakeRepo implements PartyLedgerRepository {
  _FakeRepo(this._parties, this._moves, this._anchor, this._anchorIsClosing);

  final List<PartyRef> _parties;
  final List<LedgerEntry> _moves;
  final double _anchor;
  final bool _anchorIsClosing;

  @override
  Future<List<PartyRef>> parties(LedgerKind kind) async => _parties;

  @override
  Future<PartyLedger> ledger(
          LedgerKind kind, PartyRef party, DateTime from, DateTime to) async =>
      PartyLedger.assemble(
        kind: kind,
        partyName: party.name,
        // fresh copies so a re-run starts from a clean runningBalance
        moves: [
          for (final m in _moves)
            LedgerEntry(
              date: m.date,
              type: m.type,
              docNo: m.docNo,
              detail: m.detail,
              debit: m.debit,
              credit: m.credit,
              sortKey: m.sortKey,
            ),
        ],
        anchor: _anchor,
        anchorIsClosing: _anchorIsClosing,
        from: from,
        to: to,
      );
}

void main() {
  group('PartyLedger.assemble', () {
    final from = DateTime(2026, 9, 1);
    final to = DateTime(2026, 9, 30);

    test('customer: opening is worked back from the stored closing balance', () {
      // All movements net: +1000 +8500 -5000 -1200 = +3300.
      // Stored balance (the live receivable) = 5300  => true opening = 2000.
      // The 2026-08-20 sale is before the range, so it folds into the shown
      // opening: 2000 + 1000 = 3000.
      final l = PartyLedger.assemble(
        kind: LedgerKind.customer,
        partyName: 'Ali Traders',
        moves: [
          _e('2026-08-20', 'Sale', debit: 1000), // before range -> opening
          _e('2026-09-04', 'Sale', debit: 8500, sortKey: 10),
          _e('2026-09-04', 'Receipt', credit: 5000, sortKey: 11),
          _e('2026-09-08', 'Sale Return', credit: 1200),
        ],
        anchor: 5300,
        anchorIsClosing: true,
        from: from,
        to: to,
      );

      expect(l.opening, 3000);
      expect(l.totalDebit, 8500);
      expect(l.totalCredit, 6200);
      expect(l.closing, 5300); // reconciles to the stored balance
      expect(l.entries, hasLength(3));
      expect(l.entries.first.runningBalance, 11500); // 3000 + 8500
      expect(l.entries.last.runningBalance, 5300);
    });

    test('company: opening_balance anchors from the front', () {
      final l = PartyLedger.assemble(
        kind: LedgerKind.company,
        partyName: 'Metro Cash & Carry',
        moves: [
          _e('2026-08-15', 'Purchase', debit: 3000), // before range
          _e('2026-09-10', 'Purchase', debit: 5000),
          _e('2026-09-22', 'Purchase Return', credit: 800),
        ],
        anchor: 10000, // genuine opening
        anchorIsClosing: false,
        from: from,
        to: to,
      );

      expect(l.opening, 13000); // 10000 + 3000 pre-range
      expect(l.closing, 17200); // 13000 + 5000 - 800
      expect(l.entries, hasLength(2));
      expect(l.entries.last.runningBalance, 17200);
    });

    test('same-day rows order by sortKey', () {
      final l = PartyLedger.assemble(
        kind: LedgerKind.customer,
        partyName: 'X',
        moves: [
          _e('2026-09-05', 'Receipt', credit: 500, sortKey: 11, doc: 'B'),
          _e('2026-09-05', 'Sale', debit: 900, sortKey: 10, doc: 'A'),
        ],
        anchor: 0,
        anchorIsClosing: false,
        from: from,
        to: to,
      );
      expect(l.entries.map((e) => e.docNo), ['A', 'B']);
      expect(l.entries[0].runningBalance, 900);
      expect(l.entries[1].runningBalance, 400);
    });

    test('empty ledger: closing equals opening equals anchor', () {
      final l = PartyLedger.assemble(
        kind: LedgerKind.company,
        partyName: 'Y',
        moves: const [],
        anchor: 750,
        anchorIsClosing: false,
        from: from,
        to: to,
      );
      expect(l.opening, 750);
      expect(l.closing, 750);
      expect(l.entries, isEmpty);
    });
  });

  group('PartyLedgerProvider', () {
    final wide = DateTimeRange(
        start: DateTime(2026, 1, 1), end: DateTime(2026, 12, 31));

    PartyLedgerProvider make() => PartyLedgerProvider(_FakeRepo(
          const [
            PartyRef(id: 1, name: 'Ali Traders', storedBalance: 4300),
            PartyRef(id: 2, name: 'Bilal Store', storedBalance: 0),
          ],
          [
            _e('2026-09-04', 'Sale', debit: 8500),
            _e('2026-09-08', 'Sale Return', credit: 1200),
          ],
          4300,
          true,
        ));

    test('load with preselectId picks that party and builds its ledger',
        () async {
      final p = make();
      await p.load(preselectId: 1);
      await p.setRange(wide);
      expect(p.party?.name, 'Ali Traders');
      expect(p.ledger, isNotNull);
      expect(p.ledger!.entries, hasLength(2));
      expect(p.ledger!.closing, 4300);
      expect(p.error, isNull);
    });

    test('switching kind clears the selected party', () async {
      final p = make();
      await p.load(preselectId: 1);
      await p.setKind(LedgerKind.company);
      expect(p.kind, LedgerKind.company);
      expect(p.party, isNull);
      expect(p.ledger, isNull);
    });
  });

  testWidgets('screen shows the statement with opening and closing rows',
      (tester) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final p = PartyLedgerProvider(_FakeRepo(
      const [PartyRef(id: 1, name: 'Ali Traders', storedBalance: 4300)],
      [
        _e('2026-09-04', 'Sale', debit: 8500, doc: 'SI-000181'),
        _e('2026-09-08', 'Sale Return', credit: 1200, doc: 'SR-000017'),
      ],
      4300,
      true,
    ));
    await p.load(preselectId: 1);
    await p.setRange(DateTimeRange(
        start: DateTime(2026, 1, 1), end: DateTime(2026, 12, 31)));

    await tester.pumpWidget(MaterialApp(home: PartyLedgerScreen(provider: p)));
    await tester.pumpAndSettle();

    expect(find.text('SI-000181'), findsOneWidget);
    expect(find.text('Brought forward'), findsOneWidget);
    expect(find.text('Carried forward'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
