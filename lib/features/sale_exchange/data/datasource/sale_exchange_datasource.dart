import 'package:postgres/postgres.dart';

import '../../../../config/database/database_connection.dart';
import '../../../sale_invoice/data/datasource/sale_invoice_datasource.dart';
import '../../../sale_invoice/data/model/sale_invoice_model.dart';
import '../../../sale_invoice/data/model/sale_invoice_refs.dart';
import '../model/sale_exchange_model.dart';

const _headCols =
    'id, exchange_no, exchange_date, sale_invoice_no, customer_name, '
    'old_total, new_total, difference';
const _lineCols =
    'id, sale_exchange_id, direction, product_name, unit, quantity, '
    'sale_price, line_total';

/// Talks to PostgreSQL for the Sale Exchange feature.
///
/// An exchange edits the sale invoice (via [SaleInvoiceDataSource.update]) and
/// then writes a `sale_exchange` + `sale_exchange_item` log row for Reports.
class SaleExchangeDataSource {
  const SaleExchangeDataSource();

  Connection get _conn => Database.instance.connection;

  Future<void> ensureSchema() async {
    await const SaleInvoiceDataSource().ensureSchema();
    try {
      await _conn.execute('''
        CREATE TABLE IF NOT EXISTS sale_exchange (
          id               SERIAL PRIMARY KEY,
          exchange_no      TEXT          NOT NULL DEFAULT '',
          exchange_date    DATE          NOT NULL DEFAULT CURRENT_DATE,
          sale_invoice_id  INTEGER,
          sale_invoice_no  TEXT          NOT NULL DEFAULT '',
          customer_id      INTEGER,
          customer_name    TEXT          NOT NULL DEFAULT '',
          old_total        NUMERIC(14,2) NOT NULL DEFAULT 0,
          new_total        NUMERIC(14,2) NOT NULL DEFAULT 0,
          difference       NUMERIC(14,2) NOT NULL DEFAULT 0,
          notes            TEXT          NOT NULL DEFAULT '',
          created_at       TIMESTAMPTZ   NOT NULL DEFAULT now()
        )
      ''');
      await _conn.execute('''
        CREATE TABLE IF NOT EXISTS sale_exchange_item (
          id               SERIAL PRIMARY KEY,
          sale_exchange_id INTEGER       NOT NULL
                           REFERENCES sale_exchange(id) ON DELETE CASCADE,
          direction        TEXT          NOT NULL DEFAULT 'in',
          product_id       INTEGER,
          product_name     TEXT          NOT NULL DEFAULT '',
          barcode          TEXT          NOT NULL DEFAULT '',
          unit             TEXT          NOT NULL DEFAULT 'pcs',
          quantity         NUMERIC(14,3) NOT NULL DEFAULT 0,
          sale_price       NUMERIC(14,2) NOT NULL DEFAULT 0,
          line_total       NUMERIC(14,2) NOT NULL DEFAULT 0
        )
      ''');
      await _conn.execute(
        'CREATE INDEX IF NOT EXISTS idx_sale_exchange_date '
        'ON sale_exchange(exchange_date)',
      );
      await _conn.execute(
        'CREATE INDEX IF NOT EXISTS idx_sale_exchange_item_ex_id '
        'ON sale_exchange_item(sale_exchange_id)',
      );
    } on ServerException catch (e) {
      if (e.code != '42501') rethrow;
    }
  }

  /// Every sale invoice, newest first, with its lines.
  Future<List<SaleInvoiceModel>> fetchSaleInvoices() =>
      const SaleInvoiceDataSource().fetchAll();

  /// Active products for the "add new item" picker.
  Future<List<ProductRef>> fetchProducts() =>
      const SaleInvoiceDataSource().fetchProducts();

  /// Every recorded exchange, newest first, with its moved lines. For Reports.
  Future<List<SaleExchangeRecord>> fetchAll() async {
    final heads = await _conn.execute(
      'SELECT $_headCols FROM sale_exchange '
      'ORDER BY exchange_date DESC, id DESC',
    );
    if (heads.isEmpty) return const [];

    final lineRows = await _conn.execute(
      'SELECT $_lineCols FROM sale_exchange_item '
      "ORDER BY sale_exchange_id, direction DESC, id",
    );
    final byExchange = <int, List<SaleExchangeLine>>{};
    for (final row in lineRows) {
      final m = row.toColumnMap();
      byExchange
          .putIfAbsent(m['sale_exchange_id'] as int, () => [])
          .add(SaleExchangeLine.fromMap(m));
    }

    return heads.map((row) {
      final m = row.toColumnMap();
      return SaleExchangeRecord.fromMap(
        m,
        lines: byExchange[m['id'] as int] ?? const [],
      );
    }).toList();
  }

  /// Applies the exchange: edits the sale invoice, then logs it.
  ///
  /// [updated] is [original] with its `items` already changed. [removed] /
  /// [added] are the lines that left / joined the invoice (for the log only).
  Future<void> applyExchange({
    required SaleInvoiceModel original,
    required SaleInvoiceModel updated,
    required List<SaleInvoiceItemModel> removed,
    required List<SaleInvoiceItemModel> added,
  }) async {
    // 1. The real work — stock, balance and header follow (own transaction).
    final saved = await const SaleInvoiceDataSource().update(updated);

    // 2. Log the exchange for Reports. A failure here does not undo step 1.
    try {
      await _conn.runTx((s) async {
        final r = await s.execute(
          Sql.named('''
            INSERT INTO sale_exchange
              (exchange_no, exchange_date, sale_invoice_id, sale_invoice_no,
               customer_id, customer_name, old_total, new_total, difference)
            VALUES
              ('', CURRENT_DATE, @invoice_id, @invoice_no,
               @customer_id, @customer_name, @old_total, @new_total, @difference)
            RETURNING id
          '''),
          parameters: {
            'invoice_id': original.id,
            'invoice_no': original.invoiceNo,
            'customer_id': original.customerId,
            'customer_name': original.customerName,
            'old_total': original.grandTotal,
            'new_total': saved.grandTotal,
            'difference': saved.grandTotal - original.grandTotal,
          },
        );
        final id = r.first.toColumnMap()['id'] as int;
        await s.execute(
          Sql.named("UPDATE sale_exchange "
              "SET exchange_no = 'SX-' || lpad(@id::text, 6, '0') WHERE id = @id"),
          parameters: {'id': id},
        );
        for (final entry in [
          ...removed.map((l) => ('out', l)),
          ...added.map((l) => ('in', l)),
        ]) {
          final l = entry.$2;
          await s.execute(
            Sql.named('''
              INSERT INTO sale_exchange_item
                (sale_exchange_id, direction, product_id, product_name, barcode,
                 unit, quantity, sale_price, line_total)
              VALUES
                (@ex, @dir, @pid, @name, @barcode, @unit, @qty, @price, @total)
            '''),
            parameters: {
              'ex': id,
              'dir': entry.$1,
              'pid': l.productId,
              'name': l.productName,
              'barcode': l.barcode,
              'unit': l.unit,
              'qty': l.quantity,
              'price': l.salePrice,
              'total': l.lineTotal,
            },
          );
        }
      });
    } on ServerException {
      // Log table missing / permission — the exchange itself still succeeded.
    }
  }
}
