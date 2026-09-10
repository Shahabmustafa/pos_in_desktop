import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos/features/bank/data/model/bank_head_model.dart';
import 'package:pos/features/sale_invoice/data/datasource/held_sale_invoice_datasource.dart';
import 'package:pos/features/sale_invoice/data/datasource/sale_invoice_datasource.dart';
import 'package:pos/features/sale_invoice/data/model/held_sale_invoice_model.dart';
import 'package:pos/features/sale_invoice/data/model/sale_invoice_model.dart';
import 'package:pos/features/sale_invoice/data/model/sale_invoice_refs.dart';
import 'package:pos/features/sale_invoice/data/repository/sale_invoice_repository.dart';
import 'package:pos/features/sale_invoice/presentation/provider/sale_invoice_provider.dart';
import 'package:pos/features/sale_invoice/presentation/screen/sale_invoice_screen.dart';

class _FakeSaleDataSource extends SaleInvoiceDataSource {
  _FakeSaleDataSource();
  final List<SaleInvoiceModel> rows = [];
  int _id = 1;

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
    final saved = p.copyWith(id: _id++);
    rows.add(saved);
    return saved;
  }
}

class _FakeHeldDataSource extends HeldSaleInvoiceDataSource {
  _FakeHeldDataSource();
  final List<HeldSaleInvoiceModel> rows = [];
  int _id = 1;

  @override
  Future<void> ensureSchema() async {}

  @override
  Future<List<HeldSaleInvoiceModel>> fetchAll() async =>
      rows.reversed.toList();

  @override
  Future<HeldSaleInvoiceModel> insert(HeldSaleInvoiceModel h) async {
    final saved = HeldSaleInvoiceModel(
      id: _id++,
      customerId: h.customerId,
      customerName: h.customerName,
      notes: h.notes,
      bankHeadId: h.bankHeadId,
      date: h.date,
      heldBy: h.heldBy,
      heldAt: h.heldAt,
      lines: h.lines,
    );
    rows.add(saved);
    return saved;
  }

  @override
  Future<void> delete(int id) async => rows.removeWhere((h) => h.id == id);
}

void main() {
  SaleInvoiceProvider makeProvider(_FakeHeldDataSource held) =>
      SaleInvoiceProvider(
        SaleInvoiceRepository(_FakeSaleDataSource(), held),
      );

  test('held model round-trips through its DB map', () {
    final held = HeldSaleInvoiceModel(
      customerName: 'Ali Traders',
      customerId: 2,
      notes: 'call first',
      date: DateTime(2026, 9, 10),
      lines: const [
        HeldSaleLineModel(
            productId: 10,
            productName: 'Coca-Cola 1.5L',
            quantity: 3,
            price: 120,
            discountFlat: 20),
      ],
    );
    final params = held.toInsertParams();
    expect(params['item_count'], 1);
    expect(params['grand_total'], 340); // 3*120 - 20

    final back = HeldSaleInvoiceModel.fromMap({
      'id': 7,
      'customer_id': 2,
      'customer_name': 'Ali Traders',
      'notes': 'call first',
      'invoice_date': '2026-09-10',
      'held_by': 'sara',
      'lines': params['lines'],
      'created_at': '2026-09-10T10:00:00Z',
    });
    expect(back.id, 7);
    expect(back.lines, hasLength(1));
    expect(back.lines.first.productId, 10);
    expect(back.lines.first.price, 120);
    expect(back.grandTotal, 340);
  });

  test('provider holds, lists and deletes a held invoice', () async {
    final held = _FakeHeldDataSource();
    final p = makeProvider(held);
    await p.load();
    expect(p.heldInvoices, isEmpty);

    final ok = await p.hold(HeldSaleInvoiceModel(
      customerName: 'Ali Traders',
      date: DateTime(2026, 9, 10),
      lines: const [
        HeldSaleLineModel(productId: 10, quantity: 2, price: 120),
      ],
    ));
    expect(ok, isTrue);
    expect(p.heldInvoices, hasLength(1));
    expect(p.heldInvoices.first.grandTotal, 240);

    await p.deleteHeld(p.heldInvoices.first.id!);
    expect(p.heldInvoices, isEmpty);
    expect(held.rows, isEmpty);
  });

  testWidgets('Hold button parks the cart and a Held chip then appears',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final held = _FakeHeldDataSource();
    final p = makeProvider(held);
    await tester.pumpWidget(MaterialApp(home: SaleInvoiceScreen(provider: p)));
    await tester.pumpAndSettle();

    // No hold chip while there is nothing held; the Hold button is present.
    expect(find.textContaining('Held '), findsNothing);
    expect(find.text('Hold'), findsOneWidget);

    // Add a product, then hold.
    final row = find.text('Coca-Cola 1.5L');
    await tester.tap(row);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(row);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hold'));
    await tester.pumpAndSettle();

    expect(held.rows, hasLength(1));
    expect(find.text('Cart is empty'), findsOneWidget);
    expect(find.textContaining('Held 1'), findsOneWidget);

    // Open the held list and resume it.
    await tester.tap(find.textContaining('Held 1'));
    await tester.pumpAndSettle();
    expect(find.text('Held invoices'), findsOneWidget);
    await tester.tap(find.text('Walk-in Customer').last);
    await tester.pumpAndSettle();

    expect(find.text('Cart is empty'), findsNothing);
    expect(held.rows, isEmpty); // consumed on resume
  });
}
