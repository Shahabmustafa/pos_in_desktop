import 'package:postgres/postgres.dart';

import '../../../../config/database/database_connection.dart';
import '../../../customer/data/datasource/customer_datasource.dart'
    show kWalkInCustomerName;
import '../model/dashboard_model.dart';

/// Talks to PostgreSQL for the Dashboard feature.
///
/// Everything is read-only aggregation over the tables the other features own
/// (`sale_invoice`, `sale_invoice_item`, `stock_item`, `expense_entry`). A
/// section whose table does not exist yet simply reads as zero / empty instead
/// of failing the whole dashboard.
class DashboardDataSource {
  const DashboardDataSource();

  Connection get _conn => Database.instance.connection;

  /// The single query bundle behind the dashboard.
  Future<DashboardSummary> fetchSummary() async {
    final sales = await _todaySales();
    return DashboardSummary(
      totalSale: sales.total,
      creditSale: sales.credit,
      cashSale: sales.cash,
      totalStockValue: await _guard(_stockValue, 0.0),
      stockItemCount: await _guard(_stockCount, 0),
      totalExpense: await _guard(_todayExpense, 0.0),
      dailySales: await _guard(_dailySales, const <DailySalePoint>[]),
      topProducts: await _guard(_topProducts, const <TopProductRow>[]),
    );
  }

  ({double total, double cash, double credit}) _emptySales() =>
      (total: 0, cash: 0, credit: 0);

  Future<({double total, double cash, double credit})> _todaySales() {
    return _guard(() async {
      final r = await _conn.execute(
        Sql.named('''
          SELECT
            COALESCE(SUM(grand_total), 0) AS total,
            COALESCE(SUM(grand_total) FILTER (
              WHERE customer_id IS NULL
                 OR lower(customer_name) = lower(@walkin)), 0) AS cash,
            COALESCE(SUM(grand_total) FILTER (
              WHERE customer_id IS NOT NULL
                AND lower(customer_name) <> lower(@walkin)), 0) AS credit
          FROM sale_invoice
          WHERE invoice_date = CURRENT_DATE
        '''),
        parameters: {'walkin': kWalkInCustomerName},
      );
      final m = r.first.toColumnMap();
      return (
        total: _toDouble(m['total']),
        cash: _toDouble(m['cash']),
        credit: _toDouble(m['credit']),
      );
    }, _emptySales());
  }

  Future<double> _stockValue() async {
    final r = await _conn.execute(
      "SELECT COALESCE(SUM(quantity * purchase_price), 0) AS v "
      "FROM stock_item WHERE is_active = TRUE",
    );
    return _toDouble(r.first.toColumnMap()['v']);
  }

  Future<int> _stockCount() async {
    final r = await _conn.execute(
      "SELECT COUNT(*) AS c FROM stock_item WHERE is_active = TRUE",
    );
    return _toInt(r.first.toColumnMap()['c']);
  }

  Future<double> _todayExpense() async {
    final r = await _conn.execute(
      "SELECT COALESCE(SUM(amount), 0) AS v FROM expense_entry "
      "WHERE entry_date = CURRENT_DATE",
    );
    return _toDouble(r.first.toColumnMap()['v']);
  }

  Future<List<DailySalePoint>> _dailySales() async {
    final rows = await _conn.execute('''
      SELECT (CURRENT_DATE - g) AS day,
             COALESCE(SUM(si.grand_total), 0) AS total
      FROM generate_series(0, 29) AS g
      LEFT JOIN sale_invoice si ON si.invoice_date = CURRENT_DATE - g
      GROUP BY day
      ORDER BY day
    ''');
    return rows.map((row) {
      final m = row.toColumnMap();
      return DailySalePoint(
        date: m['day'] as DateTime,
        total: _toDouble(m['total']),
      );
    }).toList();
  }

  Future<List<TopProductRow>> _topProducts() async {
    final rows = await _conn.execute('''
      SELECT sii.product_name           AS name,
             COALESCE(SUM(sii.quantity), 0)   AS qty,
             COALESCE(SUM(sii.line_total), 0) AS amount
      FROM sale_invoice_item sii
      JOIN sale_invoice si ON si.id = sii.sale_invoice_id
      WHERE si.invoice_date >= date_trunc('month', CURRENT_DATE)
      GROUP BY sii.product_name
      HAVING SUM(sii.quantity) > 0
      ORDER BY qty DESC, amount DESC
      LIMIT 20
    ''');
    return rows.map((row) {
      final m = row.toColumnMap();
      return TopProductRow(
        name: (m['name'] as String?)?.trim().isNotEmpty == true
            ? (m['name'] as String).trim()
            : '(unnamed)',
        quantity: _toDouble(m['qty']),
        amount: _toDouble(m['amount']),
      );
    }).toList();
  }

  /// Runs [query], but swallows "table/column does not exist" and
  /// "permission denied" so a not-yet-created feature table just reads as
  /// [fallback] rather than breaking the whole dashboard.
  Future<T> _guard<T>(Future<T> Function() query, T fallback) async {
    try {
      return await query();
    } on ServerException catch (e) {
      // 42P01 undefined_table, 42703 undefined_column, 42501 insufficient_privilege
      if (e.code == '42P01' || e.code == '42703' || e.code == '42501') {
        return fallback;
      }
      rethrow;
    }
  }

  static double _toDouble(Object? v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static int _toInt(Object? v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }
}
