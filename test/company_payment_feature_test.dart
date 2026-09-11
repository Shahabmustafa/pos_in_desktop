import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos/shared/app_icon.dart';

import 'package:pos/features/bank/data/model/bank_head_model.dart';
import 'package:pos/features/company_payment/data/datasource/company_payment_datasource.dart';
import 'package:pos/features/company_payment/data/model/company_payable_ref.dart';
import 'package:pos/features/company_payment/data/model/company_payment_model.dart';
import 'package:pos/features/company_payment/data/repository/company_payment_repository.dart';
import 'package:pos/features/company_payment/presentation/provider/company_payment_provider.dart';
import 'package:pos/features/company_payment/presentation/screen/company_payment_screen.dart';

/// Mimics the real datasource's live "currently payable" figure (kept in
/// [payables]) without touching Postgres or purchase_invoice/purchase_return.
class _FakeDataSource extends CompanyPaymentDataSource {
  _FakeDataSource(this.payables);

  final Map<int, double> payables;
  final List<CompanyPaymentModel> rows = [];
  int _id = 1;

  @override
  Future<void> ensureSchema() async {}

  @override
  Future<List<CompanyPaymentModel>> fetchAll() async => List.of(rows);

  @override
  Future<List<CompanyPayableRef>> fetchCompanies() async => [
        for (final e in payables.entries)
          CompanyPayableRef(id: e.key, name: 'Company ${e.key}', payable: e.value),
      ];

  @override
  Future<List<BankHeadModel>> fetchBanks() async => const [];

  @override
  Future<CompanyPaymentModel> insert(CompanyPaymentModel p) async {
    final saved = p.copyWith(id: _id++, paymentNo: 'SP-${_id.toString().padLeft(4, '0')}');
    rows.add(saved);
    payables[p.companyId] = (payables[p.companyId] ?? 0) - p.amount;
    return saved;
  }

  @override
  Future<CompanyPaymentModel> update(CompanyPaymentModel p) async {
    final i = rows.indexWhere((e) => e.id == p.id);
    final old = rows[i];
    payables[old.companyId] = (payables[old.companyId] ?? 0) + old.amount;
    payables[p.companyId] = (payables[p.companyId] ?? 0) - p.amount;
    rows[i] = p;
    return p;
  }

  @override
  Future<void> delete(int id) async {
    final row = rows.firstWhere((e) => e.id == id);
    payables[row.companyId] = (payables[row.companyId] ?? 0) + row.amount;
    rows.removeWhere((e) => e.id == id);
  }
}

void main() {
  CompanyPaymentProvider makeProvider(Map<int, double> payables) =>
      CompanyPaymentProvider(CompanyPaymentRepository(_FakeDataSource(payables)));

  test('paying a company lowers what is payable and totals paid', () async {
    final p = makeProvider({1: 1000});
    await p.load();
    expect(p.payableFor(1), 1000);

    final ok = await p.save(CompanyPaymentModel(
      date: DateTime(2026, 9, 1),
      companyId: 1,
      companyName: 'Company 1',
      amount: 400,
    ));

    expect(ok, isTrue);
    expect(p.totalPaid, 400);
    expect(p.payableFor(1), 600);
  });

  test('deleting a payment adds the amount back to what is payable', () async {
    final p = makeProvider({1: 1000});
    await p.load();
    await p.save(CompanyPaymentModel(
      date: DateTime(2026, 9, 1),
      companyId: 1,
      companyName: 'Company 1',
      amount: 400,
    ));
    expect(p.payableFor(1), 600);

    await p.delete(p.items.single.id!);
    expect(p.payableFor(1), 1000);
    expect(p.totalPaid, 0);
  });

  test('nextNumber increments with the number of payments recorded', () async {
    final p = makeProvider({1: 1000});
    await p.load();
    expect(p.nextNumber(), 'SP-0001');
    await p.save(CompanyPaymentModel(
      date: DateTime(2026, 9, 1),
      companyId: 1,
      companyName: 'Company 1',
      amount: 100,
    ));
    expect(p.nextNumber(), 'SP-0002');
  });

  testWidgets('screen lists a payment and opens the edit form', (tester) async {
    tester.view.physicalSize = const Size(1300, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final p = makeProvider({1: 1000});
    await p.load();
    await p.save(CompanyPaymentModel(
      date: DateTime(2026, 9, 1),
      companyId: 1,
      companyName: 'Company 1',
      amount: 400,
    ));

    await tester.pumpWidget(MaterialApp(home: CompanyPaymentScreen(provider: p)));
    await tester.pumpAndSettle();

    expect(find.text('Company 1'), findsOneWidget);
    expect(find.text('Pay Company'), findsWidgets);

    await tester.tap(find
        .byWidgetPredicate((w) => w is AppIcon && w.name == AppIcons.edit_outlined)
        .first);
    await tester.pumpAndSettle();
    expect(find.text('Edit Payment'), findsOneWidget);
  });
}
