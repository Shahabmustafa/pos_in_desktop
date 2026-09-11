import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos/shared/app_icon.dart';

import 'package:pos/features/bank/data/model/bank_head_model.dart';
import 'package:pos/features/customer_payment/data/datasource/customer_payment_datasource.dart';
import 'package:pos/features/customer_payment/data/model/customer_payment_model.dart';
import 'package:pos/features/customer_payment/data/repository/customer_payment_repository.dart';
import 'package:pos/features/customer_payment/presentation/provider/customer_payment_provider.dart';
import 'package:pos/features/customer_payment/presentation/screen/customer_payment_screen.dart';
import 'package:pos/features/sale_invoice/data/model/sale_invoice_refs.dart';

/// Mimics the real datasource's effect on `customer.opening_balance` (kept in
/// [balances]) without touching Postgres, so provider-level tests can assert
/// on `dueFor` the same way the real feature updates it.
class _FakeDataSource extends CustomerPaymentDataSource {
  _FakeDataSource(this.balances);

  final Map<int, double> balances;
  final List<CustomerPaymentModel> rows = [];
  int _id = 1;

  @override
  Future<void> ensureSchema() async {}

  @override
  Future<List<CustomerPaymentModel>> fetchAll() async => List.of(rows);

  @override
  Future<List<CustomerRef>> fetchCustomers() async => [
        for (final e in balances.entries)
          CustomerRef(id: e.key, name: 'Customer ${e.key}', openingBalance: e.value),
      ];

  @override
  Future<List<BankHeadModel>> fetchBanks() async => const [];

  @override
  Future<CustomerPaymentModel> insert(CustomerPaymentModel p) async {
    final saved = p.copyWith(id: _id++, paymentNo: 'CP-${_id.toString().padLeft(4, '0')}');
    rows.add(saved);
    balances[p.customerId] = (balances[p.customerId] ?? 0) - p.amount;
    return saved;
  }

  @override
  Future<CustomerPaymentModel> update(CustomerPaymentModel p) async {
    final i = rows.indexWhere((e) => e.id == p.id);
    final old = rows[i];
    balances[old.customerId] = (balances[old.customerId] ?? 0) + old.amount;
    balances[p.customerId] = (balances[p.customerId] ?? 0) - p.amount;
    rows[i] = p;
    return p;
  }

  @override
  Future<void> delete(int id) async {
    final row = rows.firstWhere((e) => e.id == id);
    balances[row.customerId] = (balances[row.customerId] ?? 0) + row.amount;
    rows.removeWhere((e) => e.id == id);
  }
}

void main() {
  CustomerPaymentProvider makeProvider(Map<int, double> balances) =>
      CustomerPaymentProvider(CustomerPaymentRepository(_FakeDataSource(balances)));

  test('collecting a payment lowers the customer due and totals collected', () async {
    final p = makeProvider({1: 1000});
    await p.load();
    expect(p.dueFor(1), 1000);

    final ok = await p.save(CustomerPaymentModel(
      date: DateTime(2026, 9, 1),
      customerId: 1,
      customerName: 'Customer 1',
      amount: 400,
    ));

    expect(ok, isTrue);
    expect(p.totalCollected, 400);
    expect(p.dueFor(1), 600);
  });

  test('deleting a payment adds the amount back to the due', () async {
    final p = makeProvider({1: 1000});
    await p.load();
    await p.save(CustomerPaymentModel(
      date: DateTime(2026, 9, 1),
      customerId: 1,
      customerName: 'Customer 1',
      amount: 400,
    ));
    expect(p.dueFor(1), 600);

    await p.delete(p.items.single.id!);
    expect(p.dueFor(1), 1000);
    expect(p.totalCollected, 0);
  });

  test('nextNumber increments with the number of payments recorded', () async {
    final p = makeProvider({1: 1000});
    await p.load();
    expect(p.nextNumber(), 'CP-0001');
    await p.save(CustomerPaymentModel(
      date: DateTime(2026, 9, 1),
      customerId: 1,
      customerName: 'Customer 1',
      amount: 100,
    ));
    expect(p.nextNumber(), 'CP-0002');
  });

  testWidgets('screen lists a payment and opens the edit form', (tester) async {
    tester.view.physicalSize = const Size(1300, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final p = makeProvider({1: 1000});
    await p.load();
    await p.save(CustomerPaymentModel(
      date: DateTime(2026, 9, 1),
      customerId: 1,
      customerName: 'Customer 1',
      amount: 400,
    ));

    await tester.pumpWidget(MaterialApp(home: CustomerPaymentScreen(provider: p)));
    await tester.pumpAndSettle();

    expect(find.text('Customer 1'), findsOneWidget);
    expect(find.text('Receive Payment'), findsWidgets);

    await tester.tap(find
        .byWidgetPredicate((w) => w is AppIcon && w.name == AppIcons.edit_outlined)
        .first);
    await tester.pumpAndSettle();
    expect(find.text('Edit Payment'), findsOneWidget);
  });
}
