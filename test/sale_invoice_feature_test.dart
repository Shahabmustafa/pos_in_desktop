import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos/features/bank/data/model/bank_head_model.dart';
import 'package:pos/features/sale_invoice/data/datasource/sale_invoice_datasource.dart';
import 'package:pos/features/sale_invoice/data/model/sale_invoice_model.dart';
import 'package:pos/features/sale_invoice/data/model/sale_invoice_refs.dart';
import 'package:pos/features/sale_invoice/data/repository/sale_invoice_repository.dart';
import 'package:pos/features/sale_invoice/presentation/provider/sale_invoice_provider.dart';
import 'package:pos/features/sale_invoice/presentation/screen/sale_invoice_screen.dart';

class _FakeDataSource extends SaleInvoiceDataSource {
  _FakeDataSource();

  final List<SaleInvoiceModel> rows = [];
  int _id = 1;

  /// Pretend on-hand stock, keyed by product id.
  final Map<int, double> stock = {10: 5, 11: 100};

  void _assertStock(SaleInvoiceModel p) {
    final needed = <int, double>{};
    for (final l in p.items) {
      if (l.productId == null) continue;
      needed[l.productId!] = (needed[l.productId!] ?? 0) + l.quantity;
    }
    needed.forEach((id, qty) {
      if (qty > (stock[id] ?? 0)) {
        throw InsufficientStockException('Not enough stock for product #$id');
      }
    });
  }

  @override
  Future<void> ensureSchema() async {}

  @override
  Future<List<BankHeadModel>> fetchBanks() async => const [];

  @override
  Future<List<SaleInvoiceModel>> fetchAll() async => List.of(rows);

  @override
  Future<List<CustomerRef>> fetchCustomers() async => const [
        CustomerRef(id: 1, name: 'Walk-in Customer'),
        CustomerRef(id: 2, name: 'Ali Traders'),
      ];

  @override
  Future<List<ProductRef>> fetchProducts() async => const [
        ProductRef(id: 10, name: 'Coca-Cola 1.5L', unit: 'pcs', salePrice: 120),
        ProductRef(id: 11, name: 'Lays 62g', unit: 'pcs', salePrice: 70),
      ];

  @override
  Future<SaleInvoiceModel> insert(SaleInvoiceModel p) async {
    _assertStock(p);
    final saved = p.copyWith(id: _id++);
    rows.add(saved);
    return saved;
  }

  @override
  Future<SaleInvoiceModel> update(SaleInvoiceModel p) async {
    _assertStock(p);
    rows[rows.indexWhere((e) => e.id == p.id)] = p;
    return p;
  }

  @override
  Future<void> delete(int id) async => rows.removeWhere((e) => e.id == id);
}

void main() {
  SaleInvoiceProvider makeProvider() =>
      SaleInvoiceProvider(SaleInvoiceRepository(_FakeDataSource()));

  test('line totals with a per-line discount (% and flat)', () {
    final inv = SaleInvoiceModel(
      date: DateTime(2026, 9, 1),
      items: const [
        // 10 x 100 = 1000, 10% disc = 100, flat 50 → disc 150, net 850,
        // 16% tax on 850 = 136 → line 986
        SaleInvoiceItemModel(
            productId: 1,
            quantity: 10,
            salePrice: 100,
            discount: 10,
            discountFlat: 50,
            tax: 16),
        // 2 x 50 = 100, no disc/tax
        SaleInvoiceItemModel(productId: 2, quantity: 2, salePrice: 50),
      ],
    );

    expect(inv.subtotal, 1100);
    expect(inv.discountTotal, closeTo(150, 0.001));
    expect(inv.taxTotal, closeTo(136, 0.001));
    expect(inv.grandTotal, closeTo(1086, 0.001));
  });

  test('per-line and per-invoice profit from the cost snapshot', () {
    final inv = SaleInvoiceModel(
      date: DateTime(2026, 9, 1),
      items: const [
        // sell 5 @ 100 (cost 60), flat 40 disc → revenue 460, cost 300
        SaleInvoiceItemModel(
            productId: 1,
            quantity: 5,
            salePrice: 100,
            purchasePrice: 60,
            discountFlat: 40),
        // sell 2 @ 200 (cost 150) = revenue 400, cost 300
        SaleInvoiceItemModel(
            productId: 2, quantity: 2, salePrice: 200, purchasePrice: 150),
      ],
    );

    expect(inv.items.first.costTotal, 300);
    expect(inv.items.first.profit, 160); // 460 - 300
    expect(inv.costTotal, 600);
    expect(inv.grandTotal, 860); // 460 + 400
    expect(inv.profit, 260); // 860 - 600
  });

  test('line discount never exceeds the line gross', () {
    const line = SaleInvoiceItemModel(
        productId: 1, quantity: 1, salePrice: 100, discountFlat: 9999);
    expect(line.discountAmount, 100);
    expect(line.lineTotal, 0);
  });

  test('provider creates, lists, updates and deletes an invoice', () async {
    final p = makeProvider();
    await p.load();
    expect(p.items, isEmpty);
    expect(p.customers, hasLength(2));
    expect(p.products, hasLength(2));

    final ok = await p.save(SaleInvoiceModel(
      date: DateTime(2026, 9, 1),
      customerId: 2,
      customerName: 'Ali Traders',
      items: const [
        SaleInvoiceItemModel(
            productId: 10, productName: 'Coca-Cola 1.5L', quantity: 3, salePrice: 120),
      ],
    ));
    expect(ok, isTrue);
    expect(p.items, hasLength(1));
    expect(p.items.first.grandTotal, 360);
    expect(p.totalSales, 360);

    await p.delete(p.items.first.id!);
    expect(p.items, isEmpty);
  });

  test('a sale beyond the on-hand stock is rejected', () async {
    final p = makeProvider();
    await p.load();

    // Only 5 of product 10 in stock — selling 8 must fail.
    final ok = await p.save(SaleInvoiceModel(
      date: DateTime(2026, 9, 1),
      customerId: 1,
      customerName: 'Walk-in',
      items: const [
        SaleInvoiceItemModel(
            productId: 10, productName: 'Coca-Cola 1.5L', quantity: 8, salePrice: 120),
      ],
    ));

    expect(ok, isFalse);
    expect(p.items, isEmpty);
    expect(p.error, contains('Not enough stock'));
  });

  testWidgets('POS builder adds to cart and shows the per-line flat discount',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final p = makeProvider();
    await tester.pumpWidget(MaterialApp(home: SaleInvoiceScreen(provider: p)));
    await tester.pumpAndSettle();

    expect(find.text('Sale Invoice'), findsOneWidget);
    expect(find.text('Coca-Cola 1.5L'), findsOneWidget);
    expect(find.text('Cart is empty'), findsOneWidget);
    // The walk-in customer is pre-selected so a quick sale needs no picking.
    expect(find.text('Walk-in Customer'), findsWidgets);
    expect(p.walkInCustomer?.id, 1);

    final row = find.text('Coca-Cola 1.5L');
    await tester.tap(row);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.text('Cart is empty'), findsNothing);
    expect(find.text('Grand Total'), findsOneWidget);
    // The cart carries both a % and a flat (Rs) discount column per line.
    expect(find.text('Disc %'), findsOneWidget);
    expect(find.text('Disc Rs'), findsOneWidget);
  });
}
