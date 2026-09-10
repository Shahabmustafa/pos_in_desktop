import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos/features/bank/data/datasource/bank_datasource.dart';
import 'package:pos/features/bank/data/model/bank_entry_model.dart';
import 'package:pos/features/bank/data/model/bank_head_model.dart';
import 'package:pos/features/bank/data/repository/bank_repository.dart';
import 'package:pos/features/bank/presentation/provider/bank_provider.dart';
import 'package:pos/features/bank/presentation/screen/bank_screen.dart';

class _FakeBankDataSource extends BankDataSource {
  _FakeBankDataSource();

  final List<BankHeadModel> heads = [];
  final List<BankEntryModel> entries = [];
  int _hId = 1;
  int _eId = 1;

  @override
  Future<void> ensureSchema() async {}

  @override
  Future<List<BankHeadModel>> fetchHeads() async => List.of(heads);

  @override
  Future<BankHeadModel> insertHead(BankHeadModel h) async {
    final saved = h.copyWith(id: _hId++);
    heads.add(saved);
    return saved;
  }

  @override
  Future<BankHeadModel> updateHead(BankHeadModel h) async {
    heads[heads.indexWhere((e) => e.id == h.id)] = h;
    return h;
  }

  @override
  Future<void> deleteHead(int id) async {
    heads.removeWhere((e) => e.id == id);
    entries.removeWhere((e) => e.bankHeadId == id);
  }

  @override
  Future<Map<int, double>> headBalances() async {
    final map = <int, double>{};
    for (final h in heads) {
      final delta = entries
          .where((e) => e.bankHeadId == h.id)
          .fold<double>(0, (a, e) => a + e.signedAmount);
      map[h.id!] = h.openingBalance + delta;
    }
    return map;
  }

  @override
  Future<List<BankEntryModel>> fetchEntries({int? headId}) async => entries
      .where((e) => headId == null || e.bankHeadId == headId)
      .toList();

  @override
  Future<void> insertEntry(BankEntryModel e) async =>
      entries.add(e.copyWith(id: _eId++));

  @override
  Future<void> updateEntry(BankEntryModel e) async =>
      entries[entries.indexWhere((x) => x.id == e.id)] = e;

  @override
  Future<void> deleteEntry(int id) async =>
      entries.removeWhere((e) => e.id == id);
}

void main() {
  BankProvider makeProvider() =>
      BankProvider(BankRepository(_FakeBankDataSource()));

  test('head balance = opening + deposits - withdrawals', () async {
    final p = makeProvider();
    await p.load();

    await p.saveHead(const BankHeadModel(title: 'Meezan', openingBalance: 1000));
    final headId = p.heads.first.id!;

    await p.saveEntry(BankEntryModel(
      bankHeadId: headId,
      date: DateTime(2026, 1, 1),
      type: BankEntryType.deposit,
      amount: 500,
    ));
    await p.saveEntry(BankEntryModel(
      bankHeadId: headId,
      date: DateTime(2026, 1, 2),
      type: BankEntryType.withdraw,
      amount: 200,
    ));

    expect(p.balanceOf(headId), 1300);
    expect(p.totalBalance, 1300);
    expect(p.entries, hasLength(2));
  });

  test('filter entries by head', () async {
    final p = makeProvider();
    await p.load();
    await p.saveHead(const BankHeadModel(title: 'A'));
    await p.saveHead(const BankHeadModel(title: 'B'));
    final a = p.heads.firstWhere((h) => h.title == 'A').id!;
    final b = p.heads.firstWhere((h) => h.title == 'B').id!;

    await p.saveEntry(BankEntryModel(
        bankHeadId: a, date: DateTime.now(), type: BankEntryType.deposit, amount: 10));
    await p.saveEntry(BankEntryModel(
        bankHeadId: b, date: DateTime.now(), type: BankEntryType.deposit, amount: 20));

    await p.filterEntriesByHead(a);
    expect(p.entries, hasLength(1));
    expect(p.entries.single.bankHeadId, a);
  });

  testWidgets('screen shows both tabs', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final p = makeProvider();
    await p.saveHead(const BankHeadModel(title: 'Meezan', openingBalance: 5000));

    await tester.pumpWidget(MaterialApp(home: BankScreen(provider: p)));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Tab, 'Bank Heads'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Bank Entries'), findsOneWidget);
    expect(find.text('Meezan'), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'Bank Entries'));
    await tester.pumpAndSettle();
    expect(find.text('Add Bank Entry'), findsWidgets);
  });
}
