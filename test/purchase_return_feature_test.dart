import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos/features/purchase/data/model/purchase_model.dart';
import 'package:pos/features/purchase_return/data/datasource/purchase_return_datasource.dart';
import 'package:pos/features/purchase_return/data/repository/purchase_return_repository.dart';
import 'package:pos/features/purchase_return/presentation/provider/purchase_return_provider.dart';
import 'package:pos/features/purchase_return/presentation/screen/purchase_return_screen.dart';

/// In-memory stand-in that applies a return the way the real datasource would.
class _FakeDataSource extends PurchaseReturnDataSource {
  _FakeDataSource(this._invoices);

  final List<PurchaseModel> _invoices;

  @override
  Future<void> ensureSchema() async {}

  @override
  Future<List<PurchaseModel>> fetchPurchaseInvoices() async =>
      List.of(_invoices);

  @override
  Future<void> returnFromInvoice({
    required PurchaseModel invoice,
    required List<PurchaseReturnSelection> selections,
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

PurchaseModel _invoice() => PurchaseModel(
      id: 1,
      invoiceNo: 'PI-0001',
      date: DateTime(2026, 9, 1),
      companyId: 3,
      companyName: 'Nestlé',
      items: const [
        PurchaseItemModel(
            id: 20, productId: 200, productName: 'Milk', quantity: 10, purchasePrice: 210),
        PurchaseItemModel(
            id: 21, productId: 201, productName: 'Surf', quantity: 5, purchasePrice: 480),
      ],
    );

void main() {
  PurchaseReturnProvider makeProvider(List<PurchaseModel> inv) =>
      PurchaseReturnProvider(PurchaseReturnRepository(_FakeDataSource(inv)));

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
  });

  test('partial return shrinks the invoiced quantity', () async {
    final p = makeProvider([_invoice()]);
    await p.load();

    final inv = p.invoices.first;
    final surf = inv.items.firstWhere((i) => i.productName == 'Surf');
    final ok = await p.submitReturn(inv, [(item: surf, qty: 2)]);

    expect(ok, isTrue);
    expect(p.invoices, hasLength(1));
    final after = p.invoices.first;
    expect(after.items.firstWhere((i) => i.productName == 'Surf').quantity, 3);
  });

  testWidgets('lists invoices and opens the return panel', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final p = makeProvider([_invoice()]);
    await tester.pumpWidget(
      MaterialApp(home: PurchaseReturnScreen(provider: p)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Purchase Return'), findsOneWidget);
    expect(find.text('PI-0001'), findsOneWidget);
    expect(find.text('View'), findsOneWidget);

    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();

    expect(find.text('Confirm Return'), findsOneWidget);
    expect(find.text('Milk'), findsOneWidget);
  });
}
