import 'package:postgres/postgres.dart';

import '../../../../config/database/database_connection.dart';
import '../../../company/data/datasource/company_datasource.dart';
import '../../../stock_inventory/data/datasource/stock_inventory_datasource.dart';
import '../model/purchase_model.dart';
import '../model/purchase_refs.dart';

const _cols =
    'id, invoice_no, invoice_date, company_id, company_name, reference, notes, '
    'amount_paid, subtotal, discount_total, tax_total, grand_total';

const _itemCols =
    'id, purchase_invoice_id, product_id, product_name, barcode, unit, quantity, '
    'purchase_price, sale_price, discount, tax, line_total';

/// Talks to PostgreSQL for the Purchase Invoice feature.
///
/// An invoice is a `purchase_invoice` header row plus its `purchase_invoice_item`
/// lines.
class PurchaseDataSource {
  const PurchaseDataSource();

  Connection get _conn => Database.instance.connection;

  /// Creates the `purchase_invoice` / `purchase_invoice_item` tables if missing
  /// and migrates the older `purchase` / `purchase_item` names (and bare early
  /// tables) up to date. A permission error (42501) is ignored so the app still
  /// works when the tables were created by
  /// lib/features/purchase/data/sql/purchase.sql.
  Future<void> ensureSchema() async {
    // The invoice form picks a supplier / product from these master tables.
    await const CompanyDataSource().ensureSchema();
    await const StockInventoryDataSource().ensureSchema();

    try {
      // Rename the old tables/column from a previous app version.
      await _conn.execute(
        'ALTER TABLE IF EXISTS purchase RENAME TO purchase_invoice');
      await _conn.execute(
        'ALTER TABLE IF EXISTS purchase_item RENAME TO purchase_invoice_item');
      final legacyFk = await _conn.execute(
        "SELECT 1 FROM information_schema.columns "
        "WHERE table_name = 'purchase_invoice_item' "
        "AND column_name = 'purchase_id'",
      );
      if (legacyFk.isNotEmpty) {
        await _conn.execute(
          'ALTER TABLE purchase_invoice_item '
          'RENAME COLUMN purchase_id TO purchase_invoice_id');
      }
      await _conn.execute(
        'ALTER INDEX IF EXISTS idx_purchase_item_purchase_id '
        'RENAME TO idx_purchase_invoice_item_invoice_id');

      await _conn.execute('''
        CREATE TABLE IF NOT EXISTS purchase_invoice (
          id             SERIAL PRIMARY KEY,
          invoice_no     TEXT          NOT NULL DEFAULT '',
          invoice_date   DATE          NOT NULL DEFAULT CURRENT_DATE,
          company_id     INTEGER,
          company_name   TEXT          NOT NULL DEFAULT '',
          reference      TEXT          NOT NULL DEFAULT '',
          notes          TEXT          NOT NULL DEFAULT '',
          amount_paid    NUMERIC(14,2) NOT NULL DEFAULT 0,
          subtotal       NUMERIC(14,2) NOT NULL DEFAULT 0,
          discount_total NUMERIC(14,2) NOT NULL DEFAULT 0,
          tax_total      NUMERIC(14,2) NOT NULL DEFAULT 0,
          grand_total    NUMERIC(14,2) NOT NULL DEFAULT 0,
          created_at     TIMESTAMPTZ   NOT NULL DEFAULT now()
        )
      ''');

      // Bring an older `purchase_invoice` (from a previous app version) up to date.
      await _conn.execute('''
        ALTER TABLE purchase_invoice
          ADD COLUMN IF NOT EXISTS invoice_no     TEXT          NOT NULL DEFAULT '',
          ADD COLUMN IF NOT EXISTS invoice_date   DATE          NOT NULL DEFAULT CURRENT_DATE,
          ADD COLUMN IF NOT EXISTS company_id     INTEGER,
          ADD COLUMN IF NOT EXISTS company_name   TEXT          NOT NULL DEFAULT '',
          ADD COLUMN IF NOT EXISTS reference      TEXT          NOT NULL DEFAULT '',
          ADD COLUMN IF NOT EXISTS notes          TEXT          NOT NULL DEFAULT '',
          ADD COLUMN IF NOT EXISTS amount_paid    NUMERIC(14,2) NOT NULL DEFAULT 0,
          ADD COLUMN IF NOT EXISTS subtotal       NUMERIC(14,2) NOT NULL DEFAULT 0,
          ADD COLUMN IF NOT EXISTS discount_total NUMERIC(14,2) NOT NULL DEFAULT 0,
          ADD COLUMN IF NOT EXISTS tax_total      NUMERIC(14,2) NOT NULL DEFAULT 0,
          ADD COLUMN IF NOT EXISTS grand_total    NUMERIC(14,2) NOT NULL DEFAULT 0,
          ADD COLUMN IF NOT EXISTS created_at     TIMESTAMPTZ   NOT NULL DEFAULT now()
      ''');

      await _conn.execute('''
        CREATE TABLE IF NOT EXISTS purchase_invoice_item (
          id                  SERIAL PRIMARY KEY,
          purchase_invoice_id INTEGER   NOT NULL REFERENCES purchase_invoice(id) ON DELETE CASCADE,
          product_id     INTEGER,
          product_name   TEXT          NOT NULL DEFAULT '',
          barcode        TEXT          NOT NULL DEFAULT '',
          unit           TEXT          NOT NULL DEFAULT 'pcs',
          quantity       NUMERIC(14,3) NOT NULL DEFAULT 0,
          purchase_price NUMERIC(14,2) NOT NULL DEFAULT 0,
          sale_price     NUMERIC(14,2) NOT NULL DEFAULT 0,
          discount       NUMERIC(6,2)  NOT NULL DEFAULT 0,
          tax            NUMERIC(6,2)  NOT NULL DEFAULT 0,
          line_total     NUMERIC(14,2) NOT NULL DEFAULT 0
        )
      ''');
      // Bring an older `purchase_invoice_item` up to date.
      await _conn.execute(
        'ALTER TABLE purchase_invoice_item '
        'ADD COLUMN IF NOT EXISTS sale_price NUMERIC(14,2) NOT NULL DEFAULT 0',
      );
      await _conn.execute(
        'CREATE INDEX IF NOT EXISTS idx_purchase_invoice_item_invoice_id '
        'ON purchase_invoice_item(purchase_invoice_id)',
      );
    } on ServerException catch (e) {
      if (e.code != '42501') rethrow;
    }
  }

  /// Every invoice, newest first, with its lines attached.
  Future<List<PurchaseModel>> fetchAll() async {
    final headers = await _conn.execute(
      'SELECT $_cols FROM purchase_invoice ORDER BY invoice_date DESC, id DESC',
    );
    if (headers.isEmpty) return const [];

    final itemRows = await _conn
        .execute('SELECT $_itemCols FROM purchase_invoice_item ORDER BY id');
    final byPurchase = <int, List<PurchaseItemModel>>{};
    for (final row in itemRows) {
      final m = row.toColumnMap();
      byPurchase
          .putIfAbsent(m['purchase_invoice_id'] as int, () => [])
          .add(PurchaseItemModel.fromMap(m));
    }

    return headers.map((row) {
      final m = row.toColumnMap();
      return PurchaseModel.fromMap(
        m,
        items: byPurchase[m['id'] as int] ?? const [],
      );
    }).toList();
  }

  /// Active companies for the invoice's supplier picker. `opening_balance` is
  /// kept live by this datasource (unpaid portion of each purchase invoice),
  /// by Purchase Return and by Pay Company — the same convention as
  /// `customer.opening_balance`. Empty when the `company` table does not
  /// exist yet.
  Future<List<CompanyRef>> fetchCompanies() async {
    try {
      final r = await _conn.execute(
        'SELECT id, name, opening_balance FROM company '
        'WHERE is_active = TRUE ORDER BY name',
      );
      return r.map((row) => CompanyRef.fromMap(row.toColumnMap())).toList();
    } on ServerException {
      return const [];
    }
  }

  /// Active products for the invoice line picker. Empty when the `stock_item`
  /// table does not exist yet.
  Future<List<ProductRef>> fetchProducts() async {
    try {
      final r = await _conn.execute(
        'SELECT id, name, barcode, unit, purchase_price, sale_price, quantity FROM stock_item '
        'WHERE is_active = TRUE ORDER BY name',
      );
      return r.map((row) => ProductRef.fromMap(row.toColumnMap())).toList();
    } on ServerException {
      return const [];
    }
  }

  Future<PurchaseModel> insert(PurchaseModel p) {
    return _conn.runTx((s) async {
      final r = await s.execute(
        Sql.named('''
          INSERT INTO purchase_invoice
            (invoice_no, invoice_date, company_id, company_name, reference, notes,
             amount_paid, subtotal, discount_total, tax_total, grand_total)
          VALUES
            (@invoice_no, @invoice_date, @company_id, @company_name, @reference, @notes,
             @amount_paid, @subtotal, @discount_total, @tax_total, @grand_total)
          RETURNING $_cols
        '''),
        parameters: p.toMap()..remove('id'),
      );
      final header = r.first.toColumnMap();
      final items = await _replaceItems(s, header['id'] as int, p.items);
      // The unpaid part of the bill goes onto the company's running balance.
      await _adjustCompanyBalance(s, p.companyId, p.grandTotal - p.amountPaid);
      return PurchaseModel.fromMap(header, items: items);
    });
  }

  Future<PurchaseModel> update(PurchaseModel p) {
    return _conn.runTx((s) async {
      // Undo the balance effect the previous version of this invoice had.
      final prev = await s.execute(
        Sql.named('SELECT company_id, grand_total, amount_paid '
            'FROM purchase_invoice WHERE id = @id'),
        parameters: {'id': p.id},
      );
      if (prev.isNotEmpty) {
        final m = prev.first.toColumnMap();
        await _adjustCompanyBalance(s, m['company_id'] as int?,
            -(_num(m['grand_total']) - _num(m['amount_paid'])));
      }

      final r = await s.execute(
        Sql.named('''
          UPDATE purchase_invoice SET
            invoice_no = @invoice_no, invoice_date = @invoice_date,
            company_id = @company_id, company_name = @company_name,
            reference = @reference, notes = @notes, amount_paid = @amount_paid,
            subtotal = @subtotal, discount_total = @discount_total,
            tax_total = @tax_total, grand_total = @grand_total
          WHERE id = @id
          RETURNING $_cols
        '''),
        parameters: p.toMap(),
      );
      final items = await _replaceItems(s, p.id!, p.items);
      await _adjustCompanyBalance(s, p.companyId, p.grandTotal - p.amountPaid);
      return PurchaseModel.fromMap(r.first.toColumnMap(), items: items);
    });
  }

  Future<void> delete(int id) {
    return _conn.runTx((s) async {
      // Undo this invoice's effect on the company's balance.
      final prev = await s.execute(
        Sql.named('SELECT company_id, grand_total, amount_paid '
            'FROM purchase_invoice WHERE id = @id'),
        parameters: {'id': id},
      );
      if (prev.isNotEmpty) {
        final m = prev.first.toColumnMap();
        await _adjustCompanyBalance(s, m['company_id'] as int?,
            -(_num(m['grand_total']) - _num(m['amount_paid'])));
      }
      // Roll the invoice's lines back out of stock before removing them.
      await _stockOut(s, id);
      await s.execute(
        Sql.named(
            'DELETE FROM purchase_invoice_item WHERE purchase_invoice_id = @id'),
        parameters: {'id': id},
      );
      await s.execute(
        Sql.named('DELETE FROM purchase_invoice WHERE id = @id'),
        parameters: {'id': id},
      );
    });
  }

  static double _num(Object? v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }

  /// Adds [delta] (may be negative) to `company.opening_balance` for
  /// [companyId]. No-op for a free-typed invoice with no company.
  Future<void> _adjustCompanyBalance(
      Session s, int? companyId, double delta) async {
    if (companyId == null || delta == 0) return;
    await s.execute(
      Sql.named('UPDATE company SET opening_balance = opening_balance + @d '
          'WHERE id = @id'),
      parameters: {'d': delta, 'id': companyId},
    );
  }

  /// Deletes the invoice's existing lines and inserts [items] fresh, returning
  /// the saved rows (with their new ids). Keeps `stock_item.quantity` in step:
  /// the old lines are subtracted and the new ones added.
  Future<List<PurchaseItemModel>> _replaceItems(
    Session s,
    int purchaseId,
    List<PurchaseItemModel> items,
  ) async {
    await _stockOut(s, purchaseId);
    await s.execute(
      Sql.named(
          'DELETE FROM purchase_invoice_item WHERE purchase_invoice_id = @id'),
      parameters: {'id': purchaseId},
    );
    final saved = <PurchaseItemModel>[];
    for (final item in items) {
      final r = await s.execute(
        Sql.named('''
          INSERT INTO purchase_invoice_item
            (purchase_invoice_id, product_id, product_name, barcode, unit, quantity,
             purchase_price, sale_price, discount, tax, line_total)
          VALUES
            (@purchase_invoice_id, @product_id, @product_name, @barcode, @unit, @quantity,
             @purchase_price, @sale_price, @discount, @tax, @line_total)
          RETURNING $_itemCols
        '''),
        parameters: {
          ...(item.toMap()..remove('id')),
          'purchase_invoice_id': purchaseId,
        },
      );
      await _addStock(s, item.productId, item.quantity);
      saved.add(PurchaseItemModel.fromMap(r.first.toColumnMap()));
    }
    return saved;
  }

  /// Subtracts every current line of invoice [purchaseId] from stock (used
  /// before the lines are deleted or replaced).
  Future<void> _stockOut(Session s, int purchaseId) async {
    final rows = await s.execute(
      Sql.named('SELECT product_id, quantity FROM purchase_invoice_item '
          'WHERE purchase_invoice_id = @id'),
      parameters: {'id': purchaseId},
    );
    for (final row in rows) {
      final m = row.toColumnMap();
      final q = m['quantity'];
      final qty = q is num ? q.toDouble() : double.tryParse('$q') ?? 0;
      await _addStock(s, m['product_id'] as int?, -qty);
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
