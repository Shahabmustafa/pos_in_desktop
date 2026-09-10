/// Data model for the Dashboard feature.
///
/// One [DashboardSummary] carries every figure the dashboard shows: the KPI
/// tiles, the daily-sales bar chart and the most-sold-products list.
class DashboardSummary {
  const DashboardSummary({
    required this.totalSale,
    required this.totalStockValue,
    required this.stockItemCount,
    required this.totalExpense,
    required this.creditSale,
    required this.cashSale,
    required this.dailySales,
    required this.topProducts,
  });

  /// Sum of `sale_invoice.grand_total` for today.
  final double totalSale;

  /// Value of goods on hand: `SUM(quantity * purchase_price)` over `stock_item`.
  final double totalStockValue;

  /// Number of active rows in `stock_item`.
  final int stockItemCount;

  /// Sum of `expense_entry.amount` for today.
  final double totalExpense;

  /// Today's sales billed to a named customer account (not walk-in).
  final double creditSale;

  /// Today's sales to the walk-in customer (counter / cash sales).
  final double cashSale;

  /// Sales value per day for the last 30 days, oldest first, gaps filled with 0.
  final List<DailySalePoint> dailySales;

  /// Most-sold products this month, highest quantity first (max 20 rows).
  final List<TopProductRow> topProducts;

  static const DashboardSummary empty = DashboardSummary(
    totalSale: 0,
    totalStockValue: 0,
    stockItemCount: 0,
    totalExpense: 0,
    creditSale: 0,
    cashSale: 0,
    dailySales: <DailySalePoint>[],
    topProducts: <TopProductRow>[],
  );
}

/// One day's total sales value.
class DailySalePoint {
  const DailySalePoint({required this.date, required this.total});

  final DateTime date;
  final double total;
}

/// One product in the "most sold" ranking.
class TopProductRow {
  const TopProductRow({
    required this.name,
    required this.quantity,
    required this.amount,
  });

  final String name;
  final double quantity;
  final double amount;
}
