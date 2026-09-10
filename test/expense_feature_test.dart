import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos/features/expense/data/datasource/expense_datasource.dart';
import 'package:pos/features/expense/data/model/expense_entry_model.dart';
import 'package:pos/features/expense/data/model/expense_head_model.dart';
import 'package:pos/features/expense/data/repository/expense_repository.dart';
import 'package:pos/features/expense/presentation/provider/expense_provider.dart';
import 'package:pos/features/expense/presentation/screen/expense_screen.dart';

class _FakeExpenseDataSource extends ExpenseDataSource {
  _FakeExpenseDataSource();

  final List<ExpenseHeadModel> heads = [];
  final List<ExpenseEntryModel> entries = [];
  int _hId = 1;
  int _eId = 1;

  @override
  Future<void> ensureSchema() async {}

  @override
  Future<List<ExpenseHeadModel>> fetchHeads() async => List.of(heads);

  @override
  Future<ExpenseHeadModel> insertHead(ExpenseHeadModel h) async {
    final saved = h.copyWith(id: _hId++);
    heads.add(saved);
    return saved;
  }

  @override
  Future<ExpenseHeadModel> updateHead(ExpenseHeadModel h) async {
    heads[heads.indexWhere((e) => e.id == h.id)] = h;
    return h;
  }

  @override
  Future<void> deleteHead(int id) async {
    heads.removeWhere((e) => e.id == id);
    entries.removeWhere((e) => e.expenseHeadId == id);
  }

  @override
  Future<Map<int, double>> headTotals() async {
    final map = <int, double>{};
    for (final h in heads) {
      map[h.id!] = entries
          .where((e) => e.expenseHeadId == h.id)
          .fold<double>(0, (a, e) => a + e.amount);
    }
    return map;
  }

  @override
  Future<List<ExpenseEntryModel>> fetchEntries({int? headId}) async => entries
      .where((e) => headId == null || e.expenseHeadId == headId)
      .toList();

  @override
  Future<void> insertEntry(ExpenseEntryModel e) async =>
      entries.add(e.copyWith(id: _eId++));

  @override
  Future<void> updateEntry(ExpenseEntryModel e) async =>
      entries[entries.indexWhere((x) => x.id == e.id)] = e;

  @override
  Future<void> deleteEntry(int id) async =>
      entries.removeWhere((e) => e.id == id);
}

void main() {
  ExpenseProvider makeProvider() =>
      ExpenseProvider(ExpenseRepository(_FakeExpenseDataSource()));

  test('head total and grand total sum the entries', () async {
    final p = makeProvider();
    await p.load();

    await p.saveHead(const ExpenseHeadModel(name: 'Rent'));
    await p.saveHead(const ExpenseHeadModel(name: 'Utilities'));
    final rent = p.heads.firstWhere((h) => h.name == 'Rent').id!;
    final util = p.heads.firstWhere((h) => h.name == 'Utilities').id!;

    await p.saveEntry(ExpenseEntryModel(
        expenseHeadId: rent, date: DateTime.now(), amount: 80000));
    await p.saveEntry(ExpenseEntryModel(
        expenseHeadId: util,
        date: DateTime.now(),
        amount: 15000,
        paymentMode: ExpensePaymentMode.bank));

    expect(p.totalOf(rent), 80000);
    expect(p.grandTotal, 95000);
  });

  test('delete entry updates totals', () async {
    final p = makeProvider();
    await p.load();
    await p.saveHead(const ExpenseHeadModel(name: 'Transport'));
    final id = p.heads.first.id!;
    await p.saveEntry(ExpenseEntryModel(
        expenseHeadId: id, date: DateTime.now(), amount: 5000));
    expect(p.grandTotal, 5000);

    await p.deleteEntry(p.entries.first.id!);
    expect(p.entries, isEmpty);
    expect(p.grandTotal, 0);
  });

  testWidgets('screen shows both tabs and an entry', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final p = makeProvider();
    await p.saveHead(const ExpenseHeadModel(name: 'Rent'));
    await p.saveEntry(ExpenseEntryModel(
        expenseHeadId: p.heads.first.id!,
        date: DateTime(2026, 9, 1),
        amount: 80000));

    await tester.pumpWidget(MaterialApp(home: ExpenseScreen(provider: p)));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(Tab, 'Expense Heads'), findsOneWidget);
    expect(find.widgetWithText(Tab, 'Expense Entries'), findsOneWidget);
    expect(find.text('Rent'), findsOneWidget);

    await tester.tap(find.widgetWithText(Tab, 'Expense Entries'));
    await tester.pumpAndSettle();
    expect(find.text('Add Expense Entry'), findsWidgets);
    expect(find.text('2026-09-01'), findsOneWidget);
  });
}
