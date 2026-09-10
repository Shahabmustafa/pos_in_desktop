import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos/features/bank/data/model/bank_head_model.dart';
import 'package:pos/features/sale_invoice/data/model/sale_invoice_model.dart';
import 'package:pos/features/sale_return/data/datasource/sale_return_datasource.dart';
import 'package:pos/features/sale_return/data/repository/sale_return_repository.dart';
import 'package:pos/features/sale_return/presentation/provider/sale_return_provider.dart';
import 'package:pos/features/sale_return/presentation/screen/sale_return_screen.dart';

/// In-memory stand-in: holds sale invoices and applies a return the same way
/// the real datasource would (full = delete, partial = shrink).
class _FakeDataSource extends SaleReturnDataSource {
  _FakeDataSource(this._invoices);

  final List<SaleInvoiceModel> _invoices;

  @override
  Future<void> ensureSchema() async {}

  @override
  Future<List<BankHeadModel>> fetchBanks() async => const [];

  @override
  Future<List<SaleInvoiceModel>> fetchSaleInvoices() async =>
      List.of(_invoices);

  @override
  Future<void> returnFromInvoice({
    required SaleInvoiceModel invoice,
    required List<ReturnSelection> selections,
    int? bankHeadId,
  }) async {
    final full = selections.length == invoice.items.length &&
        selections.every((s) => (s.item.quantity - s.qty).abs() < 1e-6);
    final idx = _invoices.indexWhere((i) => i.id == invoice.id);
    if (full) {
      _invoices.removeAt(idx);
      return;
    }
    final retById = {for (final s in selections) s.item.id: s.qty};
    final kept = [
      for (final it in invoice.items)
        if (it.quantity - (retById[it.id] ?? 0) > 1e-6)
          it.copyWith(quantity: it.quantity - (retById[it.id] ?? 0)),
    ];
    _invoices[idx] = invoice.copyWith(items: kept);
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
            id: 10, productId: 100, productName: 'Milk', quantity: 4, salePrice: 240),
        SaleInvoiceItemModel(
            id: 11, productId: 101, productName: 'Surf', quantity: 2, salePrice: 520),
      ],
    );

void main() {
  SaleReturnProvider makeProvider(List<SaleInvoiceModel> inv) =>
      SaleReturnProvider(SaleReturnRepository(_FakeDataSource(inv)));

  test('full return removes the invoice from the list', () async {
    final p = makeProvider([_invoice()]);
    await p.load();
    expect(p.invoices, hasLength(1));

    final inv = p.invoices.first;
    final ok = await p.submitReturn(inv, [
      for (final it in inv.items) (item: it, qty: it.quantity),
    ]);

    expect(ok, isTrue);
    expect(p.invoices, isEmpty);
    expect(p.selected, isNull);
  });

  test('partial return shrinks the invoiced quantity', () async {
    final p = makeProvider([_invoice()]);
    await p.load();

    final inv = p.invoices.first;
    final milk = inv.items.firstWhere((i) => i.productName == 'Milk');
    final ok = await p.submitReturn(inv, [(item: milk, qty: 1)]);

    expect(ok, isTrue);
    expect(p.invoices, hasLength(1));
    final after = p.invoices.first;
    expect(after.items, hasLength(2));
    expect(after.items.firstWhere((i) => i.productName == 'Milk').quantity, 3);
  });

  testWidgets('lists invoices and opens the return panel', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final p = makeProvider([_invoice()]);
    await tester.pumpWidget(MaterialApp(home: SaleReturnScreen(provider: p)));
    await tester.pumpAndSettle();

    expect(find.text('Sale Return'), findsOneWidget);
    expect(find.text('SI-0001'), findsOneWidget);
    expect(find.text('View'), findsOneWidget);

    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm Return'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
    expect(find.text('Surf'), findsOneWidget);
    // Return-qty fields start empty and are labelled "Return Qty".
    expect(find.widgetWithText(TextField, 'Return Qty'), findsWidgets);
    expect(
      tester.widgetList<TextField>(find.byType(TextField)).every(
            (f) => (f.controller?.text ?? '').isEmpty,
          ),
      isTrue,
    );
  });
}
