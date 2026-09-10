import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos/features/reports/data/datasource/reports_datasource.dart';
import 'package:pos/features/reports/data/model/reports_model.dart';
import 'package:pos/features/sale_exchange/data/model/sale_exchange_model.dart';
import 'package:pos/features/reports/data/repository/reports_repository.dart';
import 'package:pos/features/reports/presentation/provider/reports_provider.dart';
import 'package:pos/features/reports/presentation/screen/reports_screen.dart';

const _milk = LineReportRow(
  product: 'Coca-Cola 1.5L',
  unit: 'pcs',
  quantity: 3,
  price: 120,
  discount: 20,
  lineTotal: 340,
);

class _FakeDataSource extends ReportsDataSource {
  const _FakeDataSource();

  @override
  Future<List<SaleReportInvoice>> saleReport(
          DateTime from, DateTime to) async =>
      [
        SaleReportInvoice(
          invoiceNo: 'SI-0001',
          date: DateTime(2026, 9, 3),
          customer: 'Ali Traders',
          subtotal: 360,
          discount: 20,
          tax: 0,
          grandTotal: 340,
          items: const [_milk],
        ),
      ];

  @override
  Future<List<SaleReturnReportInvoice>> saleReturnReport(
          DateTime from, DateTime to) async =>
      [
        SaleReturnReportInvoice(
          invoiceNo: 'SR-000001',
          date: DateTime(2026, 9, 4),
          customer: 'Ali Traders',
          quantity: 1,
          grandTotal: 100,
          items: const [_milk],
        ),
      ];

  @override
  Future<ProfitLossReport> profitLoss(DateTime from, DateTime to) async {
    return ProfitLossReport(
      cogs: 500,
      saleInvoices: await saleReport(from, to), // grand 340
      saleReturnInvoices: await saleReturnReport(from, to), // grand 100
      expenseEntries: [
        ExpenseReportRow(
            date: DateTime(2026, 9, 2),
            head: 'Rent',
            amount: 200,
            paymentMode: 'cash',
            description: ''),
      ],
    );
  }

  @override
  Future<List<CategoryReportRow>> categoryReport(
          DateTime from, DateTime to) async =>
      const [
        CategoryReportRow(
          category: 'Beverages',
          quantity: 20,
          saleValue: 2400,
          cost: 1900,
          items: [
            CategoryProductRow(
                product: 'Coke', quantity: 20, saleValue: 2400, cost: 1900),
          ],
        ),
      ];

  @override
  Future<List<ExpenseReportRow>> expenseReport(
          DateTime from, DateTime to) async =>
      const [];

  @override
  Future<List<StockReportRow>> stockReport(DateTime from, DateTime to) async =>
      [
        StockReportRow(
          productId: 1,
          product: 'Coca-Cola 1.5L',
          unit: 'pcs',
          closing: 40,
          movements: [
            StockMovement(
                date: DateTime(2026, 9, 2),
                docNo: 'PI-0001',
                type: 'Purchase',
                quantity: 50,
                inbound: true),
            StockMovement(
                date: DateTime(2026, 9, 4),
                docNo: 'SI-0001',
                type: 'Sale',
                quantity: 12,
                inbound: false),
            StockMovement(
                date: DateTime(2026, 9, 5),
                docNo: 'SR-000001',
                type: 'Sale Return',
                quantity: 2,
                inbound: true),
          ],
        ),
        const StockReportRow(
            productId: 2, product: 'Lays', unit: 'pcs', closing: 8),
      ];

  @override
  Future<List<SaleExchangeRecord>> saleExchangeReport(
          DateTime from, DateTime to) async =>
      [
        SaleExchangeRecord(
          exchangeNo: 'SX-000001',
          date: DateTime(2026, 9, 5),
          invoiceNo: 'SI-0001',
          customer: 'Ali Traders',
          oldTotal: 340,
          newTotal: 720,
          lines: const [
            SaleExchangeLine(
                direction: 'out',
                productName: 'Bread',
                unit: 'pcs',
                quantity: 2,
                salePrice: 120,
                lineTotal: 240),
            SaleExchangeLine(
                direction: 'in',
                productName: 'Milk',
                unit: 'pcs',
                quantity: 3,
                salePrice: 240,
                lineTotal: 720),
          ],
        ),
      ];

  @override
  Future<PurchaseReportData> purchaseReport(DateTime from, DateTime to) async =>
      PurchaseReportData.empty;
}

void main() {
  ReportsProvider makeProvider() =>
      ReportsProvider(ReportsRepository(const _FakeDataSource()));

  test('provider loads the selected report and switches type', () async {
    final p = makeProvider();
    await p.load();
    expect(p.type, ReportType.sale);
    expect(p.saleRows, hasLength(1));
    expect(p.saleRows.single.invoiceNo, 'SI-0001');
    expect(p.saleRows.single.items.single.product, 'Coca-Cola 1.5L');

    await p.setType(ReportType.profitLoss);
    expect(p.profitLoss.grossSales, 340);
    expect(p.profitLoss.saleReturns, 100);
    expect(p.profitLoss.netSales, 240);
    expect(p.profitLoss.grossProfit, closeTo(-260, 0.001)); // 240 - 500
    expect(p.profitLoss.netProfit, closeTo(-460, 0.001)); // -260 - 200

    await p.setType(ReportType.category);
    expect(p.categoryRows.single.profit, 500);
    expect(p.categoryRows.single.items.single.product, 'Coke');
  });

  test('selecting a row opens exactly one detail panel', () async {
    final p = makeProvider();
    await p.load();
    p.selectSale(p.saleRows.first);
    expect(p.selectedSale, isNotNull);

    await p.setType(ReportType.saleReturn);
    p.selectSaleReturn(p.saleReturnRows.first);
    expect(p.selectedSaleReturn, isNotNull);
    expect(p.selectedSale, isNull); // cleared on type change
  });

  testWidgets('sale report: View opens the item panel', (tester) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final p = makeProvider();
    await tester.pumpWidget(MaterialApp(home: ReportsScreen(provider: p)));
    await tester.pumpAndSettle();

    expect(find.text('SI-0001'), findsOneWidget);
    expect(find.text('Coca-Cola 1.5L'), findsNothing);

    await tester.tap(find.byTooltip('View details'));
    await tester.pumpAndSettle();
    expect(find.text('Coca-Cola 1.5L'), findsOneWidget);
    expect(find.text('Total Amount'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sale exchange report: View shows returned + added lines',
      (tester) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final p = makeProvider();
    await tester.pumpWidget(MaterialApp(home: ReportsScreen(provider: p)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sale Exchange'));
    await tester.pumpAndSettle();
    expect(find.text('SX-000001'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('View details'));
    await tester.pumpAndSettle();
    expect(find.text('Returned'), findsOneWidget);
    expect(find.text('Added'), findsOneWidget);
    expect(find.text('Difference'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  test('stock row derives opening / sold / purchased from movements', () async {
    final p = makeProvider();
    await p.setType(ReportType.stock);
    final coke = p.stockRows.firstWhere((r) => r.product == 'Coca-Cola 1.5L');
    expect(coke.purchased, 50);
    expect(coke.sold, 12);
    expect(coke.saleReturned, 2);
    expect(coke.netChange, 40); // 50 - 12 + 2
    expect(coke.opening, 0); // closing 40 - netChange 40
  });

  testWidgets('stock report: View shows the movement ledger', (tester) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final p = makeProvider();
    await tester.pumpWidget(MaterialApp(home: ReportsScreen(provider: p)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Stock'));
    await tester.pumpAndSettle();
    expect(find.text('Coca-Cola 1.5L'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('View details'));
    await tester.pumpAndSettle();
    expect(find.text('PI-0001'), findsOneWidget);
    expect(find.text('Opening'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
