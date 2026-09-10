import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos/features/dashboard/data/datasource/dashboard_datasource.dart';
import 'package:pos/features/dashboard/data/model/dashboard_model.dart';
import 'package:pos/features/dashboard/data/repository/dashboard_repository.dart';
import 'package:pos/features/dashboard/presentation/provider/dashboard_provider.dart';
import 'package:pos/features/dashboard/presentation/screen/dashboard_screen.dart';

/// Feeds the screen a fixed [DashboardSummary] so the widget test never touches
/// a database.
class _FakeDataSource extends DashboardDataSource {
  const _FakeDataSource();

  @override
  Future<DashboardSummary> fetchSummary() async {
    final today = DateTime(2026, 9, 9);
    return DashboardSummary(
      totalSale: 4285600,
      totalStockValue: 1940200,
      stockItemCount: 3120,
      totalExpense: 612900,
      creditSale: 1180450,
      cashSale: 3105150,
      dailySales: [
        for (var i = 29; i >= 0; i--)
          DailySalePoint(
            date: today.subtract(Duration(days: i)),
            total: 90000 + i * 1000,
          ),
      ],
      topProducts: [
        for (var i = 0; i < 20; i++)
          TopProductRow(
            name: 'Product ${i + 1}',
            quantity: (2000 - i * 50).toDouble(),
            amount: (400000 - i * 5000).toDouble(),
          ),
      ],
    );
  }
}

void main() {
  testWidgets('renders KPI cards, chart and top-20 list without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final provider =
        DashboardProvider(DashboardRepository(const _FakeDataSource()));

    await tester.pumpWidget(
      MaterialApp(home: DashboardScreen(provider: provider)),
    );
    await tester.pumpAndSettle();

    // KPI cards show title + value (title is upper-cased in the card).
    expect(find.text('TOTAL SALE'), findsOneWidget);
    expect(find.text('TOTAL STOCK'), findsOneWidget);
    expect(find.text('TOTAL EXPENSE'), findsOneWidget);
    expect(find.text('TOTAL CREDIT SALE'), findsOneWidget);
    expect(find.text('TOTAL CASH SALE'), findsOneWidget);
    expect(find.text('Rs 4,285,600'), findsOneWidget);

    // Panels
    expect(find.text('Sales — last 30 days'), findsOneWidget);
    expect(find.text('Most sold products'), findsOneWidget);

    // Top-20 list is complete
    expect(find.text('Product 1'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });
}
