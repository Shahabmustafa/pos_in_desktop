import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos/features/purchase/data/datasource/purchase_datasource.dart';
import 'package:pos/features/purchase/data/model/purchase_model.dart';
import 'package:pos/features/purchase/data/model/purchase_refs.dart';
import 'package:pos/features/purchase/data/repository/purchase_repository.dart';
import 'package:pos/features/purchase/presentation/provider/purchase_provider.dart';
import 'package:pos/features/purchase/presentation/screen/purchase_screen.dart';

class _FakeDataSource extends PurchaseDataSource {
  _FakeDataSource([Map<int, double>? balances])
      : balances = balances ?? {1: 0};

  /// Mimics `company.opening_balance` being mutated directly by this
  /// datasource, without touching Postgres.
  final Map<int, double> balances;
  final List<PurchaseModel> rows = [];
  int _id = 1;

  @override
  Future<void> ensureSchema() async {}

  @override
  Future<List<PurchaseModel>> fetchAll() async => List.of(rows);

  @override
  Future<List<CompanyRef>> fetchCompanies() async => [
        for (final e in balances.entries)
          CompanyRef(id: e.key, name: 'Nestlé Pakistan', openingBalance: e.value),
      ];

  @override
  Future<List<ProductRef>> fetchProducts() async => const [
        ProductRef(id: 10, name: 'Coca-Cola 1.5L', unit: 'pcs', purchasePrice: 95),
      ];

  @override
  Future<PurchaseModel> insert(PurchaseModel p) async {
    final saved = p.copyWith(id: _id++);
    rows.add(saved);
    if (p.companyId != null) {
      balances[p.companyId!] = (balances[p.companyId!] ?? 0) + p.balanceDue;
    }
    return saved;
  }

  @override
  Future<PurchaseModel> update(PurchaseModel p) async {
    rows[rows.indexWhere((e) => e.id == p.id)] = p;
    return p;
  }

  @override
  Future<void> delete(int id) async => rows.removeWhere((e) => e.id == id);
}

void main() {
  PurchaseProvider makeProvider() =>
      PurchaseProvider(PurchaseRepository(_FakeDataSource()));

  PurchaseModel invoice({
    String no = 'PI-0001',
    List<PurchaseItemModel> items = const [],
  }) =>
      PurchaseModel(
        invoiceNo: no,
        date: DateTime(2026, 9, 1),
        companyId: 1,
        companyName: 'Nestlé Pakistan',
        items: items,
      );

  test('line and invoice totals roll up from items', () {
    final p = invoice(items: const [
      // 10 x 100 = 1000, 10% disc = 900, 16% tax = 144  -> 1044
      PurchaseItemModel(
          productId: 1, quantity: 10, purchasePrice: 100, discount: 10, tax: 16),
      // 2 x 50 = 100, no disc/tax -> 100
      PurchaseItemModel(productId: 2, quantity: 2, purchasePrice: 50),
    ]);

    expect(p.subtotal, 1100);
    expect(p.discountTotal, 100);
    expect(p.taxTotal, closeTo(144, 0.001));
    expect(p.grandTotal, closeTo(1144, 0.001));
    expect(p.itemCount, 2);
  });

  test('balanceDue is what is left unpaid on the invoice', () {
    final p = invoice(items: const [
      PurchaseItemModel(productId: 1, quantity: 1, purchasePrice: 1000),
    ]).copyWith(amountPaid: 400);

    expect(p.grandTotal, 1000);
    expect(p.balanceDue, 600);
  });

  test('amount_paid round-trips through toMap/fromMap', () {
    final p = invoice().copyWith(amountPaid: 250);
    final restored = PurchaseModel.fromMap(p.toMap());
    expect(restored.amountPaid, 250);
  });

  test('partial payment at purchase time raises the company\'s opening '
      'balance by only the unpaid balance', () async {
    final p = makeProvider();
    await p.load();
    expect(p.companies.single.openingBalance, 0);

    await p.save(invoice(items: const [
      PurchaseItemModel(productId: 10, quantity: 4, purchasePrice: 95),
      // grand_total = 380
    ]).copyWith(amountPaid: 300));
    await p.load();

    // 380 - 300 paid now = 80 left on the company's balance.
    expect(p.companies.single.openingBalance, closeTo(80, 0.001));
  });

  test('provider aggregates and suggests the next number', () async {
    final p = makeProvider();
    await p.load();

    expect(p.companies, hasLength(1));
    expect(p.products, hasLength(1));
    expect(p.nextNumber(), 'PI-0001');

    await p.save(invoice(no: 'PI-0001', items: const [
      PurchaseItemModel(productId: 10, quantity: 4, purchasePrice: 95),
    ]));

    expect(p.invoiceCount, 1);
    expect(p.totalPurchases, closeTo(380, 0.001));
    expect(p.nextNumber(), 'PI-0002');
  });

  test('delete removes the invoice', () async {
    final p = makeProvider();
    await p.save(invoice());
    expect(p.items, hasLength(1));

    await p.delete(p.items.single.id!);
    expect(p.items, isEmpty);
  });

  testWidgets('POS builder shows products, invoice no and adds to cart',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final p = makeProvider();
    await tester.pumpWidget(MaterialApp(home: PurchaseScreen(provider: p)));
    await tester.pumpAndSettle();

    // Header + product list + next invoice number chip.
    expect(find.text('Purchase Invoice'), findsOneWidget);
    expect(find.text('PI-0001'), findsOneWidget);
    expect(find.text('Coca-Cola 1.5L'), findsOneWidget);
    expect(find.text('Cart is empty'), findsOneWidget);

    // Double-tap the product row → it lands in the cart.
    final row = find.text('Coca-Cola 1.5L');
    await tester.tap(row);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.text('Cart is empty'), findsNothing);
    expect(find.text('Grand Total'), findsOneWidget);
  });
}
