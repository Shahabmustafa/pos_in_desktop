import 'package:postgres/postgres.dart';

import '../../../../config/database/database_connection.dart';
import '../../../bank/data/datasource/bank_datasource.dart';
import '../../../bank/data/model/bank_head_model.dart';
import '../../../customer/data/datasource/customer_datasource.dart';
import '../../../sale_invoice/data/datasource/sale_invoice_datasource.dart';
import '../../../sale_invoice/data/model/sale_invoice_model.dart';
import '../../../stock_inventory/data/datasource/stock_inventory_datasource.dart';
import '../model/sale_return_model.dart';
import '../model/sale_return_refs.dart';

const _cols =
    'id, invoice_no, return_date, customer_id, customer_name, notes, '
    'amount_paid, bank_head_id, subtotal, discount_total, tax_total, grand_total';

const _itemCols =
    'id, sale_return_id, product_id, product_name, barcode, unit, quantity, '
    'sale_price, discount, discount_flat, tax, line_total';

/// One product line the user chose to return, taken off an existing sale
/// invoice line together with the quantity being sent back.
typedef ReturnSelection = ({SaleInvoiceItemModel item, double qty});

/// Talks to PostgreSQL for the Sale Return feature.
///
/// A return is always made *against an existing sale invoice*. Returning every
/// line in full deletes the invoice; returning less updates the invoice in
/// place. Either way a `sale_return` header + lines are written for the record
/// (Reports reads them) — the stock and customer-balance movement comes from
/// the invoice delete / update, so the `sale_return` rows themselves carry no
/// side effects.
class SaleReturnDataSource {
  const SaleReturnDataSource();

  Connection get _conn => Database.instance.connection;

  /// Creates the `sale_return` / `sale_return_item` tables if missing and
  /// brings an older stub `sale_return` up to date. A permission error (42501)
  /// is ignored so the app still works when the tables were created by
  /// lib/features/sale_return/data/sql/sale_return.sql.
  Future<void> ensureSchema() async {
    await const CustomerDataSource().ensureSchema();
    await const CustomerDataSource().ensureWalkInCustomer();
    await const StockInventoryDataSource().ensureSchema();
    await const SaleInvoiceDataSource().ensureSchema();
    await const BankDataSource().ensureSchema();

    try {
      await _conn.execute('''
        CREATE TABLE IF NOT EXISTS sale_return (
          id                      SERIAL PRIMARY KEY,
          invoice_no              TEXT          NOT NULL DEFAULT '',
          return_date             DATE          NOT NULL DEFAULT CURRENT_DATE,
          customer_id             INTEGER,
          customer_name           TEXT          NOT NULL DEFAULT '',
          notes                   TEXT          NOT NULL DEFAULT '',
          amount_paid             NUMERIC(14,2) NOT NULL DEFAULT 0,
          subtotal                NUMERIC(14,2) NOT NULL DEFAULT 0,
          discount_total          NUMERIC(14,2) NOT NULL DEFAULT 0,
          tax_total               NUMERIC(14,2) NOT NULL DEFAULT 0,
          grand_total             NUMERIC(14,2) NOT NULL DEFAULT 0,
          created_at              TIMESTAMPTZ   NOT NULL DEFAULT now()
        )
      ''');

      await _conn.execute('''
        ALTER TABLE sale_return
          ADD COLUMN IF NOT EXISTS invoice_no              TEXT          NOT NULL DEFAULT '',
          ADD COLUMN IF NOT EXISTS return_date             DATE          NOT NULL DEFAULT CURRENT_DATE,
          ADD COLUMN IF NOT EXISTS customer_id             INTEGER,
          ADD COLUMN IF NOT EXISTS customer_name           TEXT          NOT NULL DEFAULT '',
          ADD COLUMN IF NOT EXISTS notes                   TEXT          NOT NULL DEFAULT '',
          ADD COLUMN IF NOT EXISTS amount_paid             NUMERIC(14,2) NOT NULL DEFAULT 0,
          ADD COLUMN IF NOT EXISTS bank_head_id            INTEGER,
          ADD COLUMN IF NOT EXISTS subtotal                NUMERIC(14,2) NOT NULL DEFAULT 0,
          ADD COLUMN IF NOT EXISTS discount_total          NUMERIC(14,2) NOT NULL DEFAULT 0,
          ADD COLUMN IF NOT EXISTS tax_total               NUMERIC(14,2) NOT NULL DEFAULT 0,
          ADD COLUMN IF NOT EXISTS grand_total             NUMERIC(14,2) NOT NULL DEFAULT 0,
          ADD COLUMN IF NOT EXISTS created_at              TIMESTAMPTZ   NOT NULL DEFAULT now()
      ''');

      await _conn.execute('''
        CREATE TABLE IF NOT EXISTS sale_return_item (
          id             SERIAL PRIMARY KEY,
          sale_return_id INTEGER       NOT NULL REFERENCES sale_return(id) ON DELETE CASCADE,
          product_id     INTEGER,
          product_name   TEXT          NOT NULL DEFAULT '',
          barcode        TEXT          NOT NULL DEFAULT '',
          unit           TEXT          NOT NULL DEFAULT 'pcs',
          quantity       NUMERIC(14,3) NOT NULL DEFAULT 0,
          sale_price     NUMERIC(14,2) NOT NULL DEFAULT 0,
          discount       NUMERIC(6,2)  NOT NULL DEFAULT 0,
          discount_flat  NUMERIC(14,2) NOT NULL DEFAULT 0,
          tax            NUMERIC(6,2)  NOT NULL DEFAULT 0,
          line_total     NUMERIC(14,2) NOT NULL DEFAULT 0
        )
      ''');
      await _conn.execute(
        'ALTER TABLE sale_return_item '
        'ADD COLUMN IF NOT EXISTS discount_flat NUMERIC(14,2) NOT NULL DEFAULT 0',
      );
      await _conn.execute(
        'CREATE INDEX IF NOT EXISTS idx_sale_return_item_return_id '
        'ON sale_return_item(sale_return_id)',
      );
    } on ServerException catch (e) {
      if (e.code != '42501') rethrow;
    }
  }

  /// Every sale invoice, newest first, with its lines — the list the Sale
  /// Return screen shows.
  Future<List<SaleInvoiceModel>> fetchSaleInvoices() =>
      const SaleInvoiceDataSource().fetchAll();

  /// Every return, newest first, with its lines attached. Kept for Reports.
  Future<List<SaleReturnModel>> fetchAll() async {
    final headers = await _conn.execute(
      'SELECT $_cols FROM sale_return ORDER BY return_date DESC, id DESC',
    );
    if (headers.isEmpty) return const [];

    final itemRows = await _conn
        .execute('SELECT $_itemCols FROM sale_return_item ORDER BY id');
    final byReturn = <int, List<SaleReturnItemModel>>{};
    for (final row in itemRows) {
      final m = row.toColumnMap();
      byReturn
          .putIfAbsent(m['sale_return_id'] as int, () => [])
          .add(SaleReturnItemModel.fromMap(m));
    }

    return headers.map((row) {
      final m = row.toColumnMap();
      return SaleReturnModel.fromMap(
        m,
        items: byReturn[m['id'] as int] ?? const [],
      );
    }).toList();
  }

  Future<List<CustomerRef>> fetchCustomers() async {
    try {
      final r = await _conn.execute(
        'SELECT id, name, opening_balance FROM customer WHERE is_active = TRUE ORDER BY name',
      );
      return r.map((row) => CustomerRef.fromMap(row.toColumnMap())).toList();
    } on ServerException {
      return const [];
    }
  }

  Future<List<ProductRef>> fetchProducts() async {
    try {
      final r = await _conn.execute(
        'SELECT id, name, barcode, unit, sale_price, tax, quantity '
        'FROM stock_item WHERE is_active = TRUE ORDER BY name',
      );
      return r.map((row) => ProductRef.fromMap(row.toColumnMap())).toList();
    } on ServerException {
      return const [];
    }
  }

  /// Active bank accounts for the optional "Bank" picker on the return panel.
  Future<List<BankHeadModel>> fetchBanks() async {
    try {
      final r = await _conn.execute(
        'SELECT id, title, bank_name, account_number, opening_balance, is_active '
        'FROM bank_head WHERE is_active = TRUE ORDER BY title',
      );
      return r.map((row) => BankHeadModel.fromMap(row.toColumnMap())).toList();
    } on ServerException {
      return const [];
    }
  }

  /// Returns the picked [selections] off sale invoice [invoice].
  ///
  /// * Every line returned in full  → the whole `sale_invoice` is deleted and
  ///   its effect on the customer's balance reversed.
  /// * Otherwise                    → the returned quantities are subtracted
  ///   from the invoice lines (a line hitting zero is removed), the header
  ///   totals recomputed, and the customer balance adjusted by the drop in the
  ///   invoice total.
  ///
  /// In both cases the returned goods go back onto `stock_item.quantity` and a
  /// `sale_return` header + lines are written for the record.
  Future<void> returnFromInvoice({
    required SaleInvoiceModel invoice,
    required List<ReturnSelection> selections,
    int? bankHeadId,
  }) {
    final invoiceId = invoice.id;
    if (invoiceId == null || selections.isEmpty) return Future.value();

    return _conn.runTx((s) async {
      // 1. Goods come back from the customer → add to stock.
      for (final sel in selections) {
        await _addStock(s, sel.item.productId, sel.qty);
      }

      final full = _isFullReturn(invoice, selections);

      if (full) {
        // Reverse the whole invoice's effect on the customer's balance.
        await _adjustCustomerBalance(
          s,
          invoice.customerId,
          -(invoice.grandTotal - invoice.amountReceived),
        );
        await s.execute(
          Sql.named('DELETE FROM sale_invoice_item WHERE sale_invoice_id = @id'),
          parameters: {'id': invoiceId},
        );
        await s.execute(
          Sql.named('DELETE FROM sale_invoice WHERE id = @id'),
          parameters: {'id': invoiceId},
        );
      } else {
        await _shrinkInvoice(s, invoice, selections);
      }

      // 2. Write the sale_return record (no stock / balance side effects here).
      final record = SaleReturnModel(
        returnDate: DateTime.now(),
        customerId: invoice.customerId,
        customerName: invoice.customerName,
        notes: 'Return against ${_invoiceLabel(invoice)}',
        bankHeadId: bankHeadId,
        items: [
          for (final sel in selections)
            SaleReturnItemModel(
              productId: sel.item.productId,
              productName: sel.item.productName,
              barcode: sel.item.barcode,
              unit: sel.item.unit,
              quantity: sel.qty,
              salePrice: sel.item.salePrice,
              discount: sel.item.discount,
              // Flat discount is per whole line — pro-rate it to the returned
              // share so the credited value stays right.
              discountFlat: sel.item.quantity <= 0
                  ? 0
                  : sel.item.discountFlat * (sel.qty / sel.item.quantity),
              tax: sel.item.tax,
            ),
        ],
      );
      await _insertReturnRecord(s, record);

      // 3. Refund paid from a bank account → a withdrawal on that account.
      if (bankHeadId != null && record.grandTotal != 0) {
        await s.execute(
          Sql.named('''
            INSERT INTO bank_entry (bank_head_id, entry_date, type, amount, description)
            VALUES (@h, @d, 'withdraw', @a, @desc)
          '''),
          parameters: {
            'h': bankHeadId,
            'd': record.returnDate,
            'a': record.grandTotal,
            'desc': 'Sale return against ${_invoiceLabel(invoice)}'
                '${invoice.customerName.isEmpty ? '' : ' — ${invoice.customerName}'}',
          },
        );
      }
    });
  }

  /// True when every invoice line is being returned in full.
  bool _isFullReturn(SaleInvoiceModel invoice, List<ReturnSelection> selections) {
    if (selections.length != invoice.items.length) return false;
    final qtyById = {for (final sel in selections) sel.item.id: sel.qty};
    for (final it in invoice.items) {
      final ret = qtyById[it.id];
      if (ret == null || (it.quantity - ret).abs() > 1e-6) return false;
    }
    return true;
  }

  /// Subtracts the returned quantities from the invoice's lines and rewrites
  /// the header totals.
  Future<void> _shrinkInvoice(
    Session s,
    SaleInvoiceModel invoice,
    List<ReturnSelection> selections,
  ) async {
    final retById = {for (final sel in selections) sel.item.id: sel.qty};
    final kept = <SaleInvoiceItemModel>[];

    for (final it in invoice.items) {
      final ret = retById[it.id] ?? 0;
      final keptQty = it.quantity - ret;
      if (keptQty <= 1e-6) {
        if (ret > 0) {
          await s.execute(
            Sql.named('DELETE FROM sale_invoice_item WHERE id = @id'),
            parameters: {'id': it.id},
          );
        }
        continue;
      }
      final keptItem = it.copyWith(quantity: keptQty);
      kept.add(keptItem);
      if (ret > 0) {
        await s.execute(
          Sql.named('UPDATE sale_invoice_item '
              'SET quantity = @q, line_total = @lt WHERE id = @id'),
          parameters: {'q': keptQty, 'lt': keptItem.lineTotal, 'id': it.id},
        );
      }
    }

    final shrunk = invoice.copyWith(items: kept);
    await s.execute(
      Sql.named('''
        UPDATE sale_invoice SET
          subtotal = @subtotal, discount_total = @discount_total,
          tax_total = @tax_total, grand_total = @grand_total
        WHERE id = @id
      '''),
      parameters: {
        'id': invoice.id,
        'subtotal': shrunk.subtotal,
        'discount_total': shrunk.discountTotal,
        'tax_total': shrunk.taxTotal,
        'grand_total': shrunk.grandTotal,
      },
    );

    // Mirror a normal invoice edit: with the cash received unchanged, the
    // customer's balance moves by the change in the invoice total.
    await _adjustCustomerBalance(
      s,
      invoice.customerId,
      shrunk.grandTotal - invoice.grandTotal,
    );
  }

  /// Inserts a `sale_return` header (with a server-assigned `SR-xxxxxx` number)
  /// and its lines. Deliberately does NOT touch stock or the customer balance.
  Future<void> _insertReturnRecord(Session s, SaleReturnModel p) async {
    final r = await s.execute(
      Sql.named('''
        INSERT INTO sale_return
          (invoice_no, return_date, customer_id, customer_name, notes,
           amount_paid, bank_head_id, subtotal, discount_total, tax_total, grand_total)
        VALUES
          ('', @return_date, @customer_id, @customer_name, @notes,
           @amount_paid, @bank_head_id, @subtotal, @discount_total, @tax_total, @grand_total)
        RETURNING id
      '''),
      parameters: {
        'return_date': p.returnDate,
        'customer_id': p.customerId,
        'customer_name': p.customerName,
        'notes': p.notes,
        'amount_paid': p.grandTotal,
        'bank_head_id': p.bankHeadId,
        'subtotal': p.subtotal,
        'discount_total': p.discountTotal,
        'tax_total': p.taxTotal,
        'grand_total': p.grandTotal,
      },
    );
    final id = r.first.toColumnMap()['id'] as int;
    await s.execute(
      Sql.named("UPDATE sale_return "
          "SET invoice_no = 'SR-' || lpad(@id::text, 6, '0') WHERE id = @id"),
      parameters: {'id': id},
    );
    for (final item in p.items) {
      await s.execute(
        Sql.named('''
          INSERT INTO sale_return_item
            (sale_return_id, product_id, product_name, barcode, unit, quantity,
             sale_price, discount, discount_flat, tax, line_total)
          VALUES
            (@sale_return_id, @product_id, @product_name, @barcode, @unit, @quantity,
             @sale_price, @discount, @discount_flat, @tax, @line_total)
        '''),
        parameters: {
          ...(item.toMap()..remove('id')),
          'sale_return_id': id,
        },
      );
    }
  }

  static String _invoiceLabel(SaleInvoiceModel i) =>
      i.invoiceNo.trim().isNotEmpty ? i.invoiceNo.trim() : 'invoice #${i.id}';

  /// Adds [delta] (may be negative) to `customer.opening_balance`.
  Future<void> _adjustCustomerBalance(
      Session s, int? customerId, double delta) async {
    if (customerId == null || delta == 0) return;
    await s.execute(
      Sql.named('UPDATE customer SET opening_balance = opening_balance + @d '
          'WHERE id = @id'),
      parameters: {'d': delta, 'id': customerId},
    );
  }

  /// Adds [delta] (may be negative) to `stock_item.quantity` for [productId].
  Future<void> _addStock(Session s, int? productId, double delta) async {
    if (productId == null || delta == 0) return;
    await s.execute(
      Sql.named('UPDATE stock_item SET quantity = quantity + @d WHERE id = @id'),
      parameters: {'d': delta, 'id': productId},
    );
  }

  Future<void> delete(int id) {
    return _conn.runTx((s) async {
      await s.execute(
        Sql.named('DELETE FROM sale_return_item WHERE sale_return_id = @id'),
        parameters: {'id': id},
      );
      await s.execute(
        Sql.named('DELETE FROM sale_return WHERE id = @id'),
        parameters: {'id': id},
      );
    });
  }
}
