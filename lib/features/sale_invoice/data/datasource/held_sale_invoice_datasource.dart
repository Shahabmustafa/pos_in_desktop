import 'package:postgres/postgres.dart';

import '../../../../config/database/database_connection.dart';
import '../model/held_sale_invoice_model.dart';

const _cols = 'id, customer_id, customer_name, notes, bank_head_id, '
    'invoice_date, item_count, grand_total, held_by, lines, created_at';

/// Talks to PostgreSQL for held (parked) sale invoices.
///
/// One `held_sale_invoice` row per parked cart; the lines ride along as a JSON
/// string in the `lines` column. Isolated from the main Sale Invoice datasource
/// so a hold failure never blocks a real sale.
class HeldSaleInvoiceDataSource {
  const HeldSaleInvoiceDataSource();

  Connection get _conn => Database.instance.connection;

  Future<void> ensureSchema() async {
    try {
      await _conn.execute('''
        CREATE TABLE IF NOT EXISTS held_sale_invoice (
          id            SERIAL PRIMARY KEY,
          customer_id   INTEGER,
          customer_name TEXT          NOT NULL DEFAULT '',
          notes         TEXT          NOT NULL DEFAULT '',
          bank_head_id  INTEGER,
          invoice_date  DATE          NOT NULL DEFAULT CURRENT_DATE,
          item_count    INTEGER       NOT NULL DEFAULT 0,
          grand_total   NUMERIC(14,2) NOT NULL DEFAULT 0,
          held_by       TEXT          NOT NULL DEFAULT '',
          lines         TEXT          NOT NULL DEFAULT '[]',
          created_at    TIMESTAMPTZ   NOT NULL DEFAULT now()
        )
      ''');
    } on ServerException catch (e) {
      if (e.code != '42501') rethrow;
    }
  }

  Future<List<HeldSaleInvoiceModel>> fetchAll() async {
    await ensureSchema();
    final rows = await _conn.execute(
      'SELECT $_cols FROM held_sale_invoice ORDER BY created_at DESC, id DESC',
    );
    return rows
        .map((r) => HeldSaleInvoiceModel.fromMap(r.toColumnMap()))
        .toList();
  }

  Future<HeldSaleInvoiceModel> insert(HeldSaleInvoiceModel held) async {
    await ensureSchema();
    final rows = await _conn.execute(
      Sql.named('''
        INSERT INTO held_sale_invoice
          (customer_id, customer_name, notes, bank_head_id, invoice_date,
           item_count, grand_total, held_by, lines)
        VALUES
          (@customer_id, @customer_name, @notes, @bank_head_id, @invoice_date,
           @item_count, @grand_total, @held_by, @lines)
        RETURNING $_cols
      '''),
      parameters: held.toInsertParams(),
    );
    return HeldSaleInvoiceModel.fromMap(rows.first.toColumnMap());
  }

  Future<void> delete(int id) async {
    await _conn.execute(
      Sql.named('DELETE FROM held_sale_invoice WHERE id = @id'),
      parameters: {'id': id},
    );
  }
}
