import 'package:postgres/postgres.dart';

import '../../../../config/database/database_connection.dart';
import '../../../bank/data/datasource/bank_datasource.dart';
import '../../../bank/data/model/bank_head_model.dart';
import '../../../customer/data/datasource/customer_datasource.dart';
import '../../../stock_inventory/data/datasource/stock_inventory_datasource.dart';
import '../model/sale_invoice_model.dart';
import '../model/sale_invoice_refs.dart';

const _cols =
    'id, invoice_no, invoice_date, customer_id, customer_name, notes, '
    'amount_received, bank_head_id, overall_discount, subtotal, discount_total, '
    'tax_total, grand_total';

const _itemCols =
    'id, sale_invoice_id, product_id, product_name, barcode, unit, quantity, '
    'sale_price, purchase_price, discount, discount_flat, tax, line_total';

/// Thrown when a sale invoice would drive a product's stock below zero.
class InsufficientStockException implements Exception {
  InsufficientStockException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Talks to PostgreSQL for the Sale Invoice feature.
///
/// An invoice is a `sale_invoice` header row plus its `sale_invoice_item` lines.
/// Saving an invoice reduces `stock_item.quantity` for each line.
class SaleInvoiceDataSource {
  const SaleInvoiceDataSource();

  Connection get _conn => Database.instance.connection;

  /// Creates the `sale_invoice` / `sale_invoice_item` tables if missing and
  /// brings an older stub `sale_invoice` (just an `id` column) up to date. A
  /// permission error (42501) is ignored so the app still works when the tables
  /// were created by lib/features/sale_invoice/data/sql/sale_invoice.sql.
  Future<void> ensureSchema() async {
    await const CustomerDataSource().ensureSchema();
    await const CustomerDataSource().ensureWalkInCustomer();
    await const StockInventoryDataSource().ensureSchema();
    await const BankDataSource().ensureSchema();

    try {
      await _conn.execute('''
        CREATE TABLE IF NOT EXISTS sale_invoice (
          id                      SERIAL PRIMARY KEY,
          invoice_no              TEXT          NOT NULL DEFAULT '',
          invoice_date            DATE          NOT NULL DEFAULT CURRENT_DATE,
          customer_id             INTEGER,
          customer_name           TEXT          NOT NULL DEFAULT '',
          notes                   TEXT          NOT NULL DEFAULT '',
          amount_received         NUMERIC(14,2) NOT NULL DEFAULT 0,
          bank_head_id            INTEGER,
          overall_discount        NUMERIC(6,2)  NOT NULL DEFAULT 0,
          subtotal                NUMERIC(14,2) NOT NULL DEFAULT 0,
          discount_total          NUMERIC(14,2) NOT NULL DEFAULT 0,
          tax_total               NUMERIC(14,2) NOT NULL DEFAULT 0,
          grand_total             NUMERIC(14,2) NOT NULL DEFAULT 0,
          created_at              TIMESTAMPTZ   NOT NULL DEFAULT now()
        )
      ''');

      // Bring an older `sale_invoice` (from a previous app version) up to date.
      await _conn.execute('''
        ALTER TABLE sale_invoice
          ADD COLUMN IF NOT EXISTS invoice_no              TEXT          NOT NULL DEFAULT '',
          ADD COLUMN IF NOT EXISTS invoice_date            DATE          NOT NULL DEFAULT CURRENT_DATE,
          ADD COLUMN IF NOT EXISTS customer_id             INTEGER,
          ADD COLUMN IF NOT EXISTS customer_name           TEXT          NOT NULL DEFAULT '',
          ADD COLUMN IF NOT EXISTS notes                   TEXT          NOT NULL DEFAULT '',
          ADD COLUMN IF NOT EXISTS amount_received         NUMERIC(14,2) NOT NULL DEFAULT 0,
          ADD COLUMN IF NOT EXISTS bank_head_id            INTEGER,
          ADD COLUMN IF NOT EXISTS overall_discount        NUMERIC(6,2)  NOT NULL DEFAULT 0,
          ADD COLUMN IF NOT EXISTS subtotal                NUMERIC(14,2) NOT NULL DEFAULT 0,
          ADD COLUMN IF NOT EXISTS discount_total          NUMERIC(14,2) NOT NULL DEFAULT 0,
          ADD COLUMN IF NOT EXISTS tax_total               NUMERIC(14,2) NOT NULL DEFAULT 0,
          ADD COLUMN IF NOT EXISTS grand_total             NUMERIC(14,2) NOT NULL DEFAULT 0,
          ADD COLUMN IF NOT EXISTS created_at              TIMESTAMPTZ   NOT NULL DEFAULT now()
      ''');

      await _conn.execute('''
        CREATE TABLE IF NOT EXISTS sale_invoice_item (
          id              SERIAL PRIMARY KEY,
          sale_invoice_id INTEGER       NOT NULL REFERENCES sale_invoice(id) ON DELETE CASCADE,
          product_id      INTEGER,
          product_name    TEXT          NOT NULL DEFAULT '',
          barcode         TEXT          NOT NULL DEFAULT '',
          unit            TEXT          NOT NULL DEFAULT 'pcs',
          quantity        NUMERIC(14,3) NOT NULL DEFAULT 0,
          sale_price      NUMERIC(14,2) NOT NULL DEFAULT 0,
          purchase_price  NUMERIC(14,2) NOT NULL DEFAULT 0,
          discount        NUMERIC(6,2)  NOT NULL DEFAULT 0,
          discount_flat   NUMERIC(14,2) NOT NULL DEFAULT 0,
          tax             NUMERIC(6,2)  NOT NULL DEFAULT 0,
          line_total      NUMERIC(14,2) NOT NULL DEFAULT 0
        )
      ''');
      // Bring an older `sale_invoice_item` up to date: cost snapshot for P&L,
      // and the per-line flat discount.
      await _conn.execute(
        'ALTER TABLE sale_invoice_item '
        'ADD COLUMN IF NOT EXISTS purchase_price NUMERIC(14,2) NOT NULL DEFAULT 0, '
        'ADD COLUMN IF NOT EXISTS discount_flat  NUMERIC(14,2) NOT NULL DEFAULT 0',
      );
      await _conn.execute(
        'CREATE INDEX IF NOT EXISTS idx_sale_invoice_item_invoice_id '
        'ON sale_invoice_item(sale_invoice_id)',
      );
    } on ServerException catch (e) {
      if (e.code != '42501') rethrow;
    }
  }

  /// Every invoice, newest first, with its lines attached.
  Future<List<SaleInvoiceModel>> fetchAll() async {
    final headers = await _conn.execute(
      'SELECT $_cols FROM sale_invoice ORDER BY invoice_date DESC, id DESC',
    );
    if (headers.isEmpty) return const [];

    final itemRows = await _conn
        .execute('SELECT $_itemCols FROM sale_invoice_item ORDER BY id');
    final byInvoice = <int, List<SaleInvoiceItemModel>>{};
    for (final row in itemRows) {
      final m = row.toColumnMap();
      byInvoice
          .putIfAbsent(m['sale_invoice_id'] as int, () => [])
          .add(SaleInvoiceItemModel.fromMap(m));
    }

    return headers.map((row) {
      final m = row.toColumnMap();
      return SaleInvoiceModel.fromMap(
        m,
        items: byInvoice[m['id'] as int] ?? const [],
      );
    }).toList();
  }

  /// Active customers for the invoice's customer picker. Empty when the
  /// `customer` table does not exist yet.
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

  /// Active products for the invoice line picker. Empty when the `stock_item`
  /// table does not exist yet.
  Future<List<ProductRef>> fetchProducts() async {
    try {
      final r = await _conn.execute(
        'SELECT id, name, barcode, unit, purchase_price, sale_price, tax, quantity '
        'FROM stock_item WHERE is_active = TRUE ORDER BY name',
      );
      return r.map((row) => ProductRef.fromMap(row.toColumnMap())).toList();
    } on ServerException {
      return const [];
    }
  }

  /// Active bank accounts for the optional "Bank" picker. Empty when the
  /// `bank_head` table does not exist yet.
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

  Future<SaleInvoiceModel> insert(SaleInvoiceModel p) {
    return _conn.runTx((s) async {
      final r = await s.execute(
        Sql.named('''
          INSERT INTO sale_invoice
            (invoice_no, invoice_date, customer_id, customer_name, notes,
             amount_received, bank_head_id, overall_discount, subtotal,
             discount_total, tax_total, grand_total)
          VALUES
            (@invoice_no, @invoice_date, @customer_id, @customer_name, @notes,
             @amount_received, @bank_head_id, @overall_discount, @subtotal,
             @discount_total, @tax_total, @grand_total)
          RETURNING $_cols
        '''),
        parameters: p.toMap()..remove('id'),
      );
      var header = r.first.toColumnMap();
      final id = header['id'] as int;
      // Assign a human-facing number if the caller did not supply one.
      if (((header['invoice_no'] as String?) ?? '').isEmpty) {
        final n = await s.execute(
          Sql.named("UPDATE sale_invoice "
              "SET invoice_no = 'SI-' || lpad(@id::text, 6, '0') "
              "WHERE id = @id RETURNING $_cols"),
          parameters: {'id': id},
        );
        header = n.first.toColumnMap();
      }
      final items = await _replaceItems(s, id, p.items);
      // The unpaid part of the bill goes onto the customer's running balance.
      await _adjustCustomerBalance(
          s, p.customerId, p.grandTotal - p.amountReceived);
      // Cash taken into a bank account → a deposit on that account.
      await _postBankDeposit(
        s,
        bankHeadId: p.bankHeadId,
        amount: p.amountReceived,
        date: p.date,
        description: 'Sale invoice ${(header['invoice_no'] as String?) ?? ''}'
            '${p.customerName.isEmpty ? '' : ' — ${p.customerName}'}',
      );
      return SaleInvoiceModel.fromMap(header, items: items);
    });
  }

  /// Posts a `bank_entry` deposit for [amount] against [bankHeadId]. No-op when
  /// no bank was chosen or the amount is zero.
  Future<void> _postBankDeposit(
    Session s, {
    required int? bankHeadId,
    required double amount,
    required DateTime date,
    required String description,
  }) async {
    if (bankHeadId == null || amount == 0) return;
    await s.execute(
      Sql.named('''
        INSERT INTO bank_entry (bank_head_id, entry_date, type, amount, description)
        VALUES (@h, @d, 'deposit', @a, @desc)
      '''),
      parameters: {
        'h': bankHeadId,
        'd': date,
        'a': amount,
        'desc': description.trim(),
      },
    );
  }

  Future<SaleInvoiceModel> update(SaleInvoiceModel p) {
    return _conn.runTx((s) async {
      // Undo the balance effect the previous version of this invoice had.
      final prev = await s.execute(
        Sql.named('SELECT customer_id, grand_total, amount_received '
            'FROM sale_invoice WHERE id = @id'),
        parameters: {'id': p.id},
      );
      if (prev.isNotEmpty) {
        final m = prev.first.toColumnMap();
        await _adjustCustomerBalance(s, m['customer_id'] as int?,
            -(_num(m['grand_total']) - _num(m['amount_received'])));
      }

      final r = await s.execute(
        Sql.named('''
          UPDATE sale_invoice SET
            invoice_no = @invoice_no, invoice_date = @invoice_date,
            customer_id = @customer_id, customer_name = @customer_name,
            notes = @notes, amount_received = @amount_received,
            bank_head_id = @bank_head_id, overall_discount = @overall_discount,
            subtotal = @subtotal, discount_total = @discount_total,
            tax_total = @tax_total, grand_total = @grand_total
          WHERE id = @id
          RETURNING $_cols
        '''),
        parameters: p.toMap(),
      );
      final items = await _replaceItems(s, p.id!, p.items);
      await _adjustCustomerBalance(
          s, p.customerId, p.grandTotal - p.amountReceived);
      return SaleInvoiceModel.fromMap(r.first.toColumnMap(), items: items);
    });
  }

  Future<void> delete(int id) {
    return _conn.runTx((s) async {
      // Undo this invoice's effect on the customer's balance.
      final prev = await s.execute(
        Sql.named('SELECT customer_id, grand_total, amount_received '
            'FROM sale_invoice WHERE id = @id'),
        parameters: {'id': id},
      );
      if (prev.isNotEmpty) {
        final m = prev.first.toColumnMap();
        await _adjustCustomerBalance(s, m['customer_id'] as int?,
            -(_num(m['grand_total']) - _num(m['amount_received'])));
      }
      // Put the invoice's lines back into stock before removing them.
      await _stockRestore(s, id);
      await s.execute(
        Sql.named('DELETE FROM sale_invoice_item WHERE sale_invoice_id = @id'),
        parameters: {'id': id},
      );
      await s.execute(
        Sql.named('DELETE FROM sale_invoice WHERE id = @id'),
        parameters: {'id': id},
      );
    });
  }

  static double _num(Object? v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }

  /// Adds [delta] (may be negative) to `customer.opening_balance` for
  /// [customerId]. No-op for a walk-in / free-typed invoice with no customer.
  Future<void> _adjustCustomerBalance(
      Session s, int? customerId, double delta) async {
    if (customerId == null || delta == 0) return;
    await s.execute(
      Sql.named('UPDATE customer SET opening_balance = opening_balance + @d '
          'WHERE id = @id'),
      parameters: {'d': delta, 'id': customerId},
    );
  }

  /// Deletes the invoice's existing lines and inserts [items] fresh, returning
  /// the saved rows. Keeps `stock_item.quantity` in step: old lines are added
  /// back and the new ones subtracted.
  Future<List<SaleInvoiceItemModel>> _replaceItems(
    Session s,
    int invoiceId,
    List<SaleInvoiceItemModel> items,
  ) async {
    await _stockRestore(s, invoiceId);
    await s.execute(
      Sql.named('DELETE FROM sale_invoice_item WHERE sale_invoice_id = @id'),
      parameters: {'id': invoiceId},
    );
    await _assertStockAvailable(s, items);
    final saved = <SaleInvoiceItemModel>[];
    for (final item in items) {
      final r = await s.execute(
        Sql.named('''
          INSERT INTO sale_invoice_item
            (sale_invoice_id, product_id, product_name, barcode, unit, quantity,
             sale_price, purchase_price, discount, discount_flat, tax, line_total)
          VALUES
            (@sale_invoice_id, @product_id, @product_name, @barcode, @unit, @quantity,
             @sale_price, @purchase_price, @discount, @discount_flat, @tax, @line_total)
          RETURNING $_itemCols
        '''),
        parameters: {
          ...(item.toMap()..remove('id')),
          'sale_invoice_id': invoiceId,
        },
      );
      // A sale ships goods to the customer → reduce stock.
      await _addStock(s, item.productId, -item.quantity);
      saved.add(SaleInvoiceItemModel.fromMap(r.first.toColumnMap()));
    }
    return saved;
  }

  /// Rejects the save when a line would take a product's stock below zero.
  /// Runs after the old lines were restored, so it sees the true on-hand
  /// figure for an edit. Free-typed lines (no `productId`) are skipped.
  Future<void> _assertStockAvailable(
    Session s,
    List<SaleInvoiceItemModel> items,
  ) async {
    final needed = <int, double>{};
    for (final item in items) {
      final id = item.productId;
      if (id == null || item.quantity <= 0) continue;
      needed[id] = (needed[id] ?? 0) + item.quantity;
    }

    for (final entry in needed.entries) {
      final rows = await s.execute(
        Sql.named('SELECT name, quantity FROM stock_item WHERE id = @id'),
        parameters: {'id': entry.key},
      );
      if (rows.isEmpty) continue; // product no longer in stock_item
      final m = rows.first.toColumnMap();
      final q = m['quantity'];
      final available = q is num ? q.toDouble() : double.tryParse('$q') ?? 0;
      if (entry.value > available + 1e-9) {
        final name = (m['name'] as String?) ?? 'product #${entry.key}';
        throw InsufficientStockException(
          'Not enough stock for "$name": ${_qty(available)} in hand, '
          '${_qty(entry.value)} needed.',
        );
      }
    }
  }

  static String _qty(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  /// Adds every current line of invoice [invoiceId] back into stock (used
  /// before the lines are deleted or replaced).
  Future<void> _stockRestore(Session s, int invoiceId) async {
    final rows = await s.execute(
      Sql.named('SELECT product_id, quantity FROM sale_invoice_item '
          'WHERE sale_invoice_id = @id'),
      parameters: {'id': invoiceId},
    );
    for (final row in rows) {
      final m = row.toColumnMap();
      final q = m['quantity'];
      final qty = q is num ? q.toDouble() : double.tryParse('$q') ?? 0;
      await _addStock(s, m['product_id'] as int?, qty);
    }
  }

  /// Adds [delta] (may be negative) to `stock_item.quantity` for [productId].
  Future<void> _addStock(Session s, int? productId, double delta) async {
    if (productId == null || delta == 0) return;
    await s.execute(
      Sql.named('UPDATE stock_item SET quantity = quantity + @d WHERE id = @id'),
      parameters: {'d': delta, 'id': productId},
    );
  }
}
