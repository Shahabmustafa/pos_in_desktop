import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos/features/sale_exchange/data/datasource/sale_exchange_datasource.dart';
import 'package:pos/features/sale_exchange/data/repository/sale_exchange_repository.dart';
import 'package:pos/features/sale_exchange/presentation/provider/sale_exchange_provider.dart';
import 'package:pos/features/sale_exchange/presentation/screen/sale_exchange_screen.dart';
import 'package:pos/features/sale_invoice/data/model/sale_invoice_model.dart';
import 'package:pos/features/sale_invoice/data/model/sale_invoice_refs.dart';

class _FakeDataSource extends SaleExchangeDataSource {
  _FakeDataSource(this._invoices);

  final List<SaleInvoiceModel> _invoices;

  /// Captured from the last applyExchange call.
  List<SaleInvoiceItemModel>? lastRemoved;
  List<SaleInvoiceItemModel>? lastAdded;

  @override
  Future<void> ensureSchema() async {}

  @override
  Future<List<ProductRef>> fetchProducts() async => const [
        ProductRef(id: 10, name: 'Milk', unit: 'pcs', salePrice: 240, quantity: 50),
        ProductRef(id: 11, name: 'Surf', unit: 'pcs', salePrice: 520, quantity: 30),
      ];

  @override
  Future<List<SaleInvoiceModel>> fetchSaleInvoices() async => List.of(_invoices);

  @override
  Future<void> applyExchange({
    required SaleInvoiceModel original,
    required SaleInvoiceModel updated,
    required List<SaleInvoiceItemModel> removed,
    required List<SaleInvoiceItemModel> added,
  }) async {
    lastRemoved = removed;
    lastAdded = added;
    final saved = updated.copyWith(items: [
      for (var i = 0; i < updated.items.length; i++)
        updated.items[i].copyWith(id: 100 + i),
    ]);
    _invoices[_invoices.indexWhere((e) => e.id == saved.id)] = saved;
  }
}

SaleInvoiceModel _invoice() => SaleInvoiceModel(
      id: 1,
      invoiceNo: 'SI-0001',
      date: DateTime(2026, 9, 1),
      customerId: 2,
      customerName: 'Ali Traders',
      items: const [
        SaleInvoiceItemModel(
            id: 1, productId: 100, productName: 'Bread', quantity: 2, salePrice: 120),
        SaleInvoiceItemModel(
            id: 2, productId: 101, productName: 'Eggs', quantity: 1, salePrice: 300),
      ],
    );

void main() {
  (SaleExchangeProvider, _FakeDataSource) make(List<SaleInvoiceModel> inv) {
    final ds = _FakeDataSource(inv);
    return (SaleExchangeProvider(SaleExchangeRepository(ds)), ds);
  }

  test('dropped product is logged as returned, new one as added', () async {
    final (p, ds) = make([_invoice()]);
    await p.load();
    final inv = p.invoices.first;

    // Keep "Eggs", drop "Bread", add "Milk".
    final ok = await p.applyExchange(inv, [
      inv.items.firstWhere((i) => i.productName == 'Eggs'),
      const SaleInvoiceItemModel(
          productId: 10, productName: 'Milk', quantity: 3, salePrice: 240),
    ]);

    expect(ok, isTrue);
    expect(ds.lastRemoved!.map((i) => i.productName), ['Bread']);
    expect(ds.lastAdded!.map((i) => i.productName), ['Milk']);
    final after = p.invoices.first;
    expect(after.items.map((i) => i.productName), ['Eggs', 'Milk']);
  });

  test('no change → applyExchange is a no-op', () async {
    final (p, _) = make([_invoice()]);
    await p.load();
    final ok = await p.applyExchange(p.invoices.first, p.invoices.first.items);
    expect(ok, isFalse);
  });

  test('removing every line is rejected', () async {
    final (p, _) = make([_invoice()]);
    await p.load();
    final ok = await p.applyExchange(p.invoices.first, const []);
    expect(ok, isFalse);
    expect(p.error, contains('at least one item'));
  });

  testWidgets('opening an invoice shows the cart pre-loaded with its items',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final (p, _) = make([_invoice()]);
    await tester.pumpWidget(MaterialApp(home: SaleExchangeScreen(provider: p)));
    await tester.pumpAndSettle();

    expect(find.text('SI-0001'), findsWidgets);
    await tester.tap(find.byTooltip('Exchange this invoice'));
    await tester.pumpAndSettle();

    expect(find.text('Save Exchange'), findsOneWidget);
    expect(find.text('Bread'), findsOneWidget);
    expect(find.text('Eggs'), findsOneWidget);
    expect(find.text('Grand Total'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
