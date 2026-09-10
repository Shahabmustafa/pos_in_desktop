import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos/features/cash_register/data/model/cash_register_model.dart';
import 'package:pos/features/cash_register/data/repository/cash_register_repository.dart';
import 'package:pos/features/cash_register/presentation/provider/cash_register_provider.dart';
import 'package:pos/features/cash_register/presentation/screen/cash_register_screen.dart';

CashMovement _m(
  String date, {
  double inAmt = 0,
  double outAmt = 0,
  int sortKey = 0,
  int? manualId,
  String type = 'Sale',
}) =>
    CashMovement(
      date: DateTime.parse(date),
      type: type,
      category: '',
      detail: '',
      inAmount: inAmt,
      outAmount: outAmt,
      sortKey: sortKey,
      manualId: manualId,
    );

class _FakeRepo implements CashRegisterRepository {
  _FakeRepo(this._account, this._moves);

  final CashAccount _account;
  final List<CashMovement> _moves;
  CashEntry? lastSaved;
  int? lastDeleted;

  @override
  Future<void> ensureSchema() async {}

  @override
  Future<CashAccount> account() async => _account;

  @override
  Future<CashAccount> saveAccount(CashAccount a) async => a;

  @override
  Future<CashBook> cashBook(DateTime from, DateTime to) async => CashBook.build(
        title: _account.title,
        openingFloat: _account.openingBalance,
        moves: [
          for (final m in _moves)
            CashMovement(
              date: m.date,
              type: m.type,
              category: m.category,
              detail: m.detail,
              inAmount: m.inAmount,
              outAmount: m.outAmount,
              sortKey: m.sortKey,
              manualId: m.manualId,
            ),
        ],
        from: from,
        to: to,
        asOf: DateTime(2026, 9, 30),
      );

  @override
  Future<void> saveEntry(CashEntry e) async => lastSaved = e;

  @override
  Future<void> deleteEntry(int id) async => lastDeleted = id;
}

void main() {
  group('CashBook.build', () {
    final from = DateTime(2026, 9, 1);
    final to = DateTime(2026, 9, 30);

    test('running balance walks the opening float forward', () {
      final book = CashBook.build(
        title: 'Cash in Hand',
        openingFloat: 5000,
        moves: [
          _m('2026-09-02', inAmt: 1200, sortKey: 10), // cash sale
          _m('2026-09-03', outAmt: 800, sortKey: 20, type: 'Expense'),
          _m('2026-09-05', outAmt: 2000, sortKey: 30, manualId: 1,
              type: 'Cash Out'), // bank deposit
        ],
        from: from,
        to: to,
        asOf: to,
      );

      expect(book.opening, 5000);
      expect(book.totalIn, 1200);
      expect(book.totalOut, 2800);
      expect(book.closing, 3400);
      expect(book.cashInHand, 3400);
      expect(book.entries.map((e) => e.runningBalance), [6200, 5400, 3400]);
    });

    test('movements before the range fold into the shown opening', () {
      final book = CashBook.build(
        title: 'Cash in Hand',
        openingFloat: 1000,
        moves: [
          _m('2026-08-20', inAmt: 4000), // before range
          _m('2026-09-10', inAmt: 500),
        ],
        from: from,
        to: to,
        asOf: to,
      );
      expect(book.opening, 5000); // 1000 + 4000
      expect(book.closing, 5500);
      expect(book.entries, hasLength(1));
    });

    test('cashInHand counts every movement up to asOf, ignoring the range', () {
      final book = CashBook.build(
        title: 'Cash in Hand',
        openingFloat: 0,
        moves: [
          _m('2026-09-15', inAmt: 300), // inside range
          _m('2026-09-25', inAmt: 700), // after "to", before asOf
        ],
        from: from,
        to: DateTime(2026, 9, 20),
        asOf: DateTime(2026, 9, 30),
      );
      expect(book.closing, 300); // range only
      expect(book.cashInHand, 1000); // both
    });
  });

  group('CashRegisterProvider', () {
    CashRegisterProvider make() => CashRegisterProvider(_FakeRepo(
          CashAccount(openingBalance: 5000),
          [_m('2026-09-02', inAmt: 1200)],
        ));

    test('load builds the book and reads the account', () async {
      final p = make();
      await p.setRange(DateTimeRange(
          start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 30)));
      expect(p.account.openingBalance, 5000);
      expect(p.book.entries, hasLength(1));
      expect(p.book.cashInHand, 6200);
      expect(p.error, isNull);
    });

    test('saveEntry round-trips through the repository', () async {
      final repo = _FakeRepo(CashAccount(), const []);
      final p = CashRegisterProvider(repo);
      await p.load();
      await p.saveEntry(CashEntry(
        date: DateTime(2026, 9, 4),
        direction: CashDirection.cashOut,
        amount: 2000,
        category: 'Bank deposit',
      ));
      expect(repo.lastSaved?.amount, 2000);
      expect(repo.lastSaved?.direction, CashDirection.cashOut);
    });
  });

  testWidgets('screen shows Cash in Hand and the cash book', (tester) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final p = CashRegisterProvider(_FakeRepo(
      CashAccount(openingBalance: 5000),
      [
        _m('2026-09-02', inAmt: 1200, type: 'Sale'),
        _m('2026-09-05', outAmt: 800, type: 'Expense'),
      ],
    ));
    await p.setRange(DateTimeRange(
        start: DateTime(2026, 9, 1), end: DateTime(2026, 9, 30)));

    await tester.pumpWidget(MaterialApp(home: CashRegisterScreen(provider: p)));
    await tester.pumpAndSettle();

    expect(find.text('CASH IN HAND'), findsOneWidget); // StatCard title
    expect(find.text('Brought forward'), findsOneWidget);
    expect(find.text('Carried forward'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
