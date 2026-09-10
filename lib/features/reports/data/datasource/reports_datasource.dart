import 'package:postgres/postgres.dart';

import '../../../../config/database/database_connection.dart';
import '../../../sale_exchange/data/model/sale_exchange_model.dart';
import '../model/reports_model.dart';

/// Talks to PostgreSQL for the Reports feature. Every query is read-only and
/// date-bounded; a table that does not exist yet (42P01) just yields an empty
/// result instead of failing the report.
class ReportsDataSource {
  const ReportsDataSource();

  Connection get _conn => Database.instance.connection;

  // ── Sale (invoice rows + items) ────────────────────────────────────
  Future<List<SaleReportInvoice>> saleReport(DateTime from, DateTime to) {
    return _guard(() async {
      final heads = await _conn.execute(
        Sql.named('''
          SELECT id, invoice_no, invoice_date, customer_name,
                 subtotal, discount_total, tax_total, grand_total
          FROM sale_invoice
          WHERE invoice_date >= @from::date AND invoice_date <= @to::date
          ORDER BY invoice_date, id
        '''),
        parameters: {'from': _ymd(from), 'to': _ymd(to)},
      );
      if (heads.isEmpty) return const <SaleReportInvoice>[];

      final items = await _conn.execute(
        Sql.named('''
          SELECT sii.sale_invoice_id AS invoice_id, sii.product_name, sii.unit,
                 sii.quantity, sii.sale_price AS price, sii.discount,
                 sii.discount_flat, sii.line_total
          FROM sale_invoice_item sii
          JOIN sale_invoice si ON si.id = sii.sale_invoice_id
          WHERE si.invoice_date >= @from::date AND si.invoice_date <= @to::date
          ORDER BY sii.sale_invoice_id, sii.id
        '''),
        parameters: {'from': _ymd(from), 'to': _ymd(to)},
      );
      final byInvoice = _groupItems(items);

      return heads.map((row) {
        final m = row.toColumnMap();
        return SaleReportInvoice.fromMap(m,
            items: byInvoice[m['id'] as int] ?? const []);
      }).toList();
    }, const <SaleReportInvoice>[]);
  }

  // ── Sale return (invoice rows + items) ─────────────────────────────
  Future<List<SaleReturnReportInvoice>> saleReturnReport(
      DateTime from, DateTime to) {
    return _guard(() async {
      final heads = await _conn.execute(
        Sql.named('''
          SELECT sr.id, sr.invoice_no, sr.return_date, sr.customer_name,
                 sr.grand_total,
                 COALESCE((SELECT SUM(quantity) FROM sale_return_item
                           WHERE sale_return_id = sr.id), 0) AS qty
          FROM sale_return sr
          WHERE sr.return_date >= @from::date AND sr.return_date <= @to::date
          ORDER BY sr.return_date, sr.id
        '''),
        parameters: {'from': _ymd(from), 'to': _ymd(to)},
      );
      if (heads.isEmpty) return const <SaleReturnReportInvoice>[];

      final items = await _conn.execute(
        Sql.named('''
          SELECT sri.sale_return_id AS invoice_id, sri.product_name, sri.unit,
                 sri.quantity, sri.sale_price AS price, sri.discount,
                 sri.discount_flat, sri.line_total
          FROM sale_return_item sri
          JOIN sale_return sr ON sr.id = sri.sale_return_id
          WHERE sr.return_date >= @from::date AND sr.return_date <= @to::date
          ORDER BY sri.sale_return_id, sri.id
        '''),
        parameters: {'from': _ymd(from), 'to': _ymd(to)},
      );
      final byInvoice = _groupItems(items);

      return heads.map((row) {
        final m = row.toColumnMap();
        return SaleReturnReportInvoice.fromMap(m,
            items: byInvoice[m['id'] as int] ?? const []);
      }).toList();
    }, const <SaleReturnReportInvoice>[]);
  }

  // ── Sale exchange (log rows + moved lines) ────────────────────────
  Future<List<SaleExchangeRecord>> saleExchangeReport(
      DateTime from, DateTime to) {
    return _guard(() async {
      final heads = await _conn.execute(
        Sql.named('''
          SELECT id, exchange_no, exchange_date, sale_invoice_no,
                 customer_name, old_total, new_total, difference
          FROM sale_exchange
          WHERE exchange_date >= @from::date AND exchange_date <= @to::date
          ORDER BY exchange_date, id
        '''),
        parameters: {'from': _ymd(from), 'to': _ymd(to)},
      );
      if (heads.isEmpty) return const <SaleExchangeRecord>[];

      final items = await _conn.execute(
        Sql.named('''
          SELECT ei.sale_exchange_id AS ex_id, ei.direction, ei.product_name,
                 ei.unit, ei.quantity, ei.sale_price, ei.line_total
          FROM sale_exchange_item ei
          JOIN sale_exchange e ON e.id = ei.sale_exchange_id
          WHERE e.exchange_date >= @from::date AND e.exchange_date <= @to::date
          ORDER BY ei.sale_exchange_id, ei.direction DESC, ei.id
        '''),
        parameters: {'from': _ymd(from), 'to': _ymd(to)},
      );
      final byExchange = <int, List<SaleExchangeLine>>{};
      for (final row in items) {
        final m = row.toColumnMap();
        byExchange
            .putIfAbsent(m['ex_id'] as int, () => [])
            .add(SaleExchangeLine.fromMap(m));
      }

      return heads.map((row) {
        final m = row.toColumnMap();
        return SaleExchangeRecord.fromMap(m,
            lines: byExchange[m['id'] as int] ?? const []);
      }).toList();
    }, const <SaleExchangeRecord>[]);
  }

  // ── Stock (movement per product) ─────────────────────────────────
  Future<List<StockReportRow>> stockReport(DateTime from, DateTime to) async {
    final moves = <int, List<StockMovement>>{};

    Future<void> collect(String sql, String type, bool inbound) async {
      final rows = await _guard(() async {
        return await _conn.execute(
          Sql.named(sql),
          parameters: {'from': _ymd(from), 'to': _ymd(to)},
        );
      }, null);
      if (rows == null) return;
      for (final row in rows) {
        final m = row.toColumnMap();
        final pid = m['pid'] as int;
        moves.putIfAbsent(pid, () => []).add(StockMovement(
              date: _dt(m['d']),
              docNo: (m['doc'] as String?)?.trim().isNotEmpty == true
                  ? (m['doc'] as String).trim()
                  : '—',
              type: type,
              quantity: _d(m['q']),
              inbound: inbound,
              party: (m['party'] as String?)?.trim() ?? '',
              price: _d(m['rate']),
              amount: _d(m['amt']),
            ));
      }
    }

    await collect('''
      SELECT pii.product_id AS pid, pi.invoice_date AS d, pi.invoice_no AS doc,
             pii.quantity AS q, pi.company_name AS party,
             pii.purchase_price AS rate, pii.line_total AS amt
      FROM purchase_invoice_item pii
      JOIN purchase_invoice pi ON pi.id = pii.purchase_invoice_id
      WHERE pii.product_id IS NOT NULL
        AND pi.invoice_date >= @from::date AND pi.invoice_date <= @to::date
    ''', 'Purchase', true);
    await collect('''
      SELECT sii.product_id AS pid, si.invoice_date AS d, si.invoice_no AS doc,
             sii.quantity AS q, si.customer_name AS party,
             sii.sale_price AS rate, sii.line_total AS amt
      FROM sale_invoice_item sii
      JOIN sale_invoice si ON si.id = sii.sale_invoice_id
      WHERE sii.product_id IS NOT NULL
        AND si.invoice_date >= @from::date AND si.invoice_date <= @to::date
    ''', 'Sale', false);
    await collect('''
      SELECT sri.product_id AS pid, sr.return_date AS d, sr.invoice_no AS doc,
             sri.quantity AS q, sr.customer_name AS party,
             sri.sale_price AS rate, sri.line_total AS amt
      FROM sale_return_item sri
      JOIN sale_return sr ON sr.id = sri.sale_return_id
      WHERE sri.product_id IS NOT NULL
        AND sr.return_date >= @from::date AND sr.return_date <= @to::date
    ''', 'Sale Return', true);
    await collect('''
      SELECT pri.product_id AS pid, pr.return_date AS d, pr.invoice_no AS doc,
             pri.quantity AS q, pr.company_name AS party,
             pri.unit_price AS rate, pri.line_total AS amt
      FROM purchase_return_item pri
      JOIN purchase_return pr ON pr.id = pri.purchase_return_id
      WHERE pri.product_id IS NOT NULL
        AND pr.return_date >= @from::date AND pr.return_date <= @to::date
    ''', 'Purchase Return', false);

    final snap = await _guard(() async {
      return await _conn.execute(
        'SELECT id, name, unit, quantity FROM stock_item '
        'WHERE is_active = TRUE ORDER BY name',
      );
    }, null);
    if (snap == null) return const [];

    final out = <StockReportRow>[];
    for (final row in snap) {
      final m = row.toColumnMap();
      final id = m['id'] as int;
      final ms = moves[id] ?? const <StockMovement>[];
      out.add(StockReportRow(
        productId: id,
        product: (m['name'] as String?)?.trim().isNotEmpty == true
            ? (m['name'] as String).trim()
            : '(unnamed)',
        unit: (m['unit'] as String?)?.trim() ?? 'pcs',
        closing: _d(m['quantity']),
        movements: [...ms]..sort((a, b) => a.date.compareTo(b.date)),
      ));
    }
    return out;
  }

  // ── Profit & Loss ──────────────────────────────────────────────────
  Future<ProfitLossReport> profitLoss(DateTime from, DateTime to) async {
    final sales = await saleReport(from, to);
    final returns = await saleReturnReport(from, to);
    final expenses = await expenseReport(from, to);
    final cogs = await _guard(() async {
      final r = await _conn.execute(
        Sql.named('''
          SELECT COALESCE(SUM(sii.quantity * sii.purchase_price), 0) AS cogs
          FROM sale_invoice_item sii
          JOIN sale_invoice si ON si.id = sii.sale_invoice_id
          WHERE si.invoice_date >= @from::date AND si.invoice_date <= @to::date
        '''),
        parameters: {'from': _ymd(from), 'to': _ymd(to)},
      );
      return _d(r.first.toColumnMap()['cogs']);
    }, 0.0);

    return ProfitLossReport(
      cogs: cogs,
      saleInvoices: sales,
      saleReturnInvoices: returns,
      expenseEntries: expenses,
    );
  }

  // ── Category-wise (category rows + product items) ─────────────────
  Future<List<CategoryReportRow>> categoryReport(DateTime from, DateTime to) {
    return _guard(() async {
      final rows = await _conn.execute(
        Sql.named('''
          SELECT COALESCE(NULLIF(TRIM(st.category), ''), '(uncategorised)') AS category,
                 sii.product_name,
                 COALESCE(SUM(sii.quantity), 0)                       AS qty,
                 COALESCE(SUM(sii.line_total), 0)                     AS sale_value,
                 COALESCE(SUM(sii.quantity * sii.purchase_price), 0)  AS cost
          FROM sale_invoice_item sii
          JOIN sale_invoice si ON si.id = sii.sale_invoice_id
          LEFT JOIN stock_item st ON st.id = sii.product_id
          WHERE si.invoice_date >= @from::date AND si.invoice_date <= @to::date
          GROUP BY 1, 2
          ORDER BY 1, sale_value DESC
        '''),
        parameters: {'from': _ymd(from), 'to': _ymd(to)},
      );

      final byCategory = <String, List<CategoryProductRow>>{};
      for (final row in rows) {
        final m = row.toColumnMap();
        final cat = (m['category'] as String?)?.trim().isNotEmpty == true
            ? (m['category'] as String).trim()
            : '(uncategorised)';
        byCategory
            .putIfAbsent(cat, () => [])
            .add(CategoryProductRow.fromMap(m));
      }

      final out = byCategory.entries.map((e) {
        final products = e.value;
        return CategoryReportRow(
          category: e.key,
          quantity: products.fold(0, (a, p) => a + p.quantity),
          saleValue: products.fold(0, (a, p) => a + p.saleValue),
          cost: products.fold(0, (a, p) => a + p.cost),
          items: products,
        );
      }).toList()
        ..sort((a, b) => b.saleValue.compareTo(a.saleValue));
      return out;
    }, const <CategoryReportRow>[]);
  }

  // ── Expense ────────────────────────────────────────────────────────
  Future<List<ExpenseReportRow>> expenseReport(DateTime from, DateTime to) {
    return _guard(() async {
      final r = await _conn.execute(
        Sql.named('''
          SELECT ee.entry_date, eh.name AS head, ee.amount,
                 ee.payment_mode, ee.description
          FROM expense_entry ee
          JOIN expense_head eh ON eh.id = ee.expense_head_id
          WHERE ee.entry_date >= @from::date AND ee.entry_date <= @to::date
          ORDER BY ee.entry_date, ee.id
        '''),
        parameters: {'from': _ymd(from), 'to': _ymd(to)},
      );
      return r
          .map((row) => ExpenseReportRow.fromMap(row.toColumnMap()))
          .toList();
    }, const <ExpenseReportRow>[]);
  }

  // ── Purchase (invoice rows + items) + purchase returns ────────────
  Future<PurchaseReportData> purchaseReport(DateTime from, DateTime to) async {
    final purchases = await _guard(() async {
      final heads = await _conn.execute(
        Sql.named('''
          SELECT id, invoice_no, invoice_date, company_name,
                 subtotal, discount_total, tax_total, grand_total
          FROM purchase_invoice
          WHERE invoice_date >= @from::date AND invoice_date <= @to::date
          ORDER BY invoice_date, id
        '''),
        parameters: {'from': _ymd(from), 'to': _ymd(to)},
      );
      if (heads.isEmpty) return const <PurchaseReportInvoice>[];

      final items = await _conn.execute(
        Sql.named('''
          SELECT pii.purchase_invoice_id AS invoice_id, pii.product_name,
                 pii.unit, pii.quantity, pii.purchase_price AS price,
                 pii.discount, 0 AS discount_flat, pii.line_total
          FROM purchase_invoice_item pii
          JOIN purchase_invoice pi ON pi.id = pii.purchase_invoice_id
          WHERE pi.invoice_date >= @from::date AND pi.invoice_date <= @to::date
          ORDER BY pii.purchase_invoice_id, pii.id
        '''),
        parameters: {'from': _ymd(from), 'to': _ymd(to)},
      );
      final byInvoice = _groupItems(items);

      return heads.map((row) {
        final m = row.toColumnMap();
        return PurchaseReportInvoice.fromMap(m,
            items: byInvoice[m['id'] as int] ?? const []);
      }).toList();
    }, const <PurchaseReportInvoice>[]);

    final returns = await _guard(() async {
      final r = await _conn.execute(
        Sql.named('''
          SELECT pr.id, pr.invoice_no, pr.return_date, pr.company_name AS party,
                 pr.grand_total,
                 COALESCE((SELECT SUM(quantity) FROM purchase_return_item
                           WHERE purchase_return_id = pr.id), 0) AS qty
          FROM purchase_return pr
          WHERE pr.return_date >= @from::date AND pr.return_date <= @to::date
          ORDER BY pr.return_date, pr.id
        '''),
        parameters: {'from': _ymd(from), 'to': _ymd(to)},
      );
      return r
          .map((row) => ReturnReportRow.fromMap(row.toColumnMap()))
          .toList();
    }, const <ReturnReportRow>[]);

    return PurchaseReportData(purchases: purchases, returns: returns);
  }

  // ── helpers ────────────────────────────────────────────────────────
  Map<int, List<LineReportRow>> _groupItems(Result rows) {
    final out = <int, List<LineReportRow>>{};
    for (final row in rows) {
      final m = row.toColumnMap();
      out
          .putIfAbsent(m['invoice_id'] as int, () => [])
          .add(LineReportRow.fromMap(m));
    }
    return out;
  }

  Future<T> _guard<T>(Future<T> Function() run, T fallback) async {
    try {
      return await run();
    } on ServerException catch (e) {
      if (e.code == '42P01' || e.code == '42703' || e.code == '42501') {
        return fallback;
      }
      rethrow;
    }
  }

  /// Date as a bare 'YYYY-MM-DD' string so the SQL `::date` cast is exact and
  /// free of any client/server timezone shift.
  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static double _d(Object? v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static DateTime _dt(Object? v) {
    if (v is DateTime) return v;
    return DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
  }
}
