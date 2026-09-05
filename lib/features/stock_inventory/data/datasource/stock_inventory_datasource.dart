import 'package:postgres/postgres.dart';

import '../../../../config/database/database_connection.dart';
import '../../../product_catalog/data/datasource/product_catalog_datasource.dart';
import '../model/named_ref.dart';
import '../model/stock_item_model.dart';

const _cols =
    'id, barcode, name, sku, sale_price, purchase_price, quantity, discount, tax, '
    'expiry_date, unit, company_id, company_name, inventory_type_id, '
    'inventory_type, category_id, category, is_active';

/// Talks to PostgreSQL for the Stock Inventory feature.
class StockInventoryDataSource {
  const StockInventoryDataSource();

  Connection get _conn => Database.instance.connection;

  /// Creates the `stock_item` table if missing and brings older copies up to
  /// date (including the `*_id` foreign-key columns). A permission error
  /// (42501) is ignored so the app still works when the table was created by
  /// lib/features/stock_inventory/data/sql/stock_inventory.sql.
  Future<void> ensureSchema() async {
    // The product form picks a company / category / inventory type from these
    // master tables, so make sure they exist first.
    await const ProductCatalogDataSource().ensureSchema();

    try {
      await _conn.execute('''
        CREATE TABLE IF NOT EXISTS stock_item (
          id                SERIAL PRIMARY KEY,
          barcode           TEXT          NOT NULL DEFAULT '',
          name              TEXT          NOT NULL,
          sku               TEXT          NOT NULL DEFAULT '',
          sale_price        NUMERIC(14,2) NOT NULL DEFAULT 0,
          purchase_price    NUMERIC(14,2) NOT NULL DEFAULT 0,
          quantity          NUMERIC(14,3) NOT NULL DEFAULT 0,
          discount          NUMERIC(6,2)  NOT NULL DEFAULT 0,
          tax               NUMERIC(6,2)  NOT NULL DEFAULT 0,
          expiry_date       DATE,
          unit              TEXT          NOT NULL DEFAULT 'pcs',
          company_id        INTEGER,
          company_name      TEXT          NOT NULL DEFAULT '',
          inventory_type_id INTEGER,
          inventory_type    TEXT          NOT NULL DEFAULT '',
          category_id       INTEGER,
          category          TEXT          NOT NULL DEFAULT '',
          is_active         BOOLEAN       NOT NULL DEFAULT TRUE,
          created_at        TIMESTAMPTZ   NOT NULL DEFAULT now()
        )
      ''');

      // Bring an older `stock_item` (from a previous app version) up to date.
      await _conn.execute('''
        ALTER TABLE stock_item
          ADD COLUMN IF NOT EXISTS barcode           TEXT          NOT NULL DEFAULT '',
          ADD COLUMN IF NOT EXISTS sku               TEXT          NOT NULL DEFAULT '',
          ADD COLUMN IF NOT EXISTS sale_price        NUMERIC(14,2) NOT NULL DEFAULT 0,
          ADD COLUMN IF NOT EXISTS purchase_price    NUMERIC(14,2) NOT NULL DEFAULT 0,
          ADD COLUMN IF NOT EXISTS quantity          NUMERIC(14,3) NOT NULL DEFAULT 0,
          ADD COLUMN IF NOT EXISTS discount          NUMERIC(6,2)  NOT NULL DEFAULT 0,
          ADD COLUMN IF NOT EXISTS tax               NUMERIC(6,2)  NOT NULL DEFAULT 0,
          ADD COLUMN IF NOT EXISTS expiry_date       DATE,
          ADD COLUMN IF NOT EXISTS unit              TEXT          NOT NULL DEFAULT 'pcs',
          ADD COLUMN IF NOT EXISTS company_id        INTEGER,
          ADD COLUMN IF NOT EXISTS company_name      TEXT          NOT NULL DEFAULT '',
          ADD COLUMN IF NOT EXISTS inventory_type_id INTEGER,
          ADD COLUMN IF NOT EXISTS inventory_type    TEXT          NOT NULL DEFAULT '',
          ADD COLUMN IF NOT EXISTS category_id       INTEGER,
          ADD COLUMN IF NOT EXISTS category          TEXT          NOT NULL DEFAULT '',
          ADD COLUMN IF NOT EXISTS is_active         BOOLEAN       NOT NULL DEFAULT TRUE
      ''');

      await _backfillIds();
    } on ServerException catch (e) {
      if (e.code != '42501') rethrow;
    }
  }

  /// One-time migration for rows that still carry only the old text values:
  /// move any free-typed category / inventory type into its master table, then
  /// fill `category_id` / `inventory_type_id` / `company_id`.
  Future<void> _backfillIds() async {
    // Preserve free-typed values by adding them to the master tables.
    await _conn.execute('''
      INSERT INTO product_category (name)
      SELECT DISTINCT btrim(category) FROM stock_item
      WHERE btrim(category) <> ''
        AND NOT EXISTS (
          SELECT 1 FROM product_category pc
          WHERE lower(pc.name) = lower(btrim(stock_item.category)))
      ON CONFLICT (name) DO NOTHING
    ''');
    await _conn.execute('''
      INSERT INTO inventory_type (name)
      SELECT DISTINCT btrim(inventory_type) FROM stock_item
      WHERE btrim(inventory_type) <> ''
        AND NOT EXISTS (
          SELECT 1 FROM inventory_type it
          WHERE lower(it.name) = lower(btrim(stock_item.inventory_type)))
      ON CONFLICT (name) DO NOTHING
    ''');

    await _conn.execute('''
      UPDATE stock_item s SET category_id = pc.id
      FROM product_category pc
      WHERE s.category_id IS NULL
        AND btrim(s.category) <> ''
        AND lower(pc.name) = lower(btrim(s.category))
    ''');
    await _conn.execute('''
      UPDATE stock_item s SET inventory_type_id = it.id
      FROM inventory_type it
      WHERE s.inventory_type_id IS NULL
        AND btrim(s.inventory_type) <> ''
        AND lower(it.name) = lower(btrim(s.inventory_type))
    ''');
    // The company table may not exist yet; ignore that.
    try {
      await _conn.execute('''
        UPDATE stock_item s SET company_id = co.id
        FROM company co
        WHERE s.company_id IS NULL
          AND btrim(s.company_name) <> ''
          AND lower(co.name) = lower(btrim(s.company_name))
      ''');
    } on ServerException {
      // no company table
    }
  }

  Future<List<StockItemModel>> fetchAll() async {
    final r = await _conn.execute('SELECT $_cols FROM stock_item ORDER BY name');
    return r.map((row) => StockItemModel.fromMap(row.toColumnMap())).toList();
  }

  /// Active companies for the product form's company picker.
  Future<List<NamedRef>> fetchCompanies() => _fetchRefs('company');

  /// Active categories for the product form's category picker.
  Future<List<NamedRef>> fetchCategories() => _fetchRefs('product_category');

  /// Active inventory types for the product form's type picker.
  Future<List<NamedRef>> fetchInventoryTypes() => _fetchRefs('inventory_type');

  /// `{id, name}` of every active row in [table], sorted by name. Empty list
  /// when the table does not exist yet.
  Future<List<NamedRef>> _fetchRefs(String table) async {
    try {
      final r = await _conn.execute(
        'SELECT id, name FROM $table WHERE is_active = TRUE ORDER BY name',
      );
      return r.map((row) => NamedRef.fromMap(row.toColumnMap())).toList();
    } on ServerException {
      return const [];
    }
  }

  Future<StockItemModel> insert(StockItemModel i) async {
    final r = await _conn.execute(
      Sql.named('''
        INSERT INTO stock_item
          (barcode, name, sku, sale_price, purchase_price, quantity, discount, tax,
           expiry_date, unit, company_id, company_name, inventory_type_id,
           inventory_type, category_id, category, is_active)
        VALUES
          (@barcode, @name, @sku, @sale_price, @purchase_price, @quantity, @discount, @tax,
           @expiry_date, @unit, @company_id, @company_name, @inventory_type_id,
           @inventory_type, @category_id, @category, @is_active)
        RETURNING $_cols
      '''),
      parameters: i.toMap()..remove('id'),
    );
    return StockItemModel.fromMap(r.first.toColumnMap());
  }

  Future<StockItemModel> update(StockItemModel i) async {
    final r = await _conn.execute(
      Sql.named('''
        UPDATE stock_item SET
          barcode = @barcode, name = @name, sku = @sku,
          sale_price = @sale_price, purchase_price = @purchase_price,
          quantity = @quantity,
          discount = @discount, tax = @tax, expiry_date = @expiry_date,
          unit = @unit,
          company_id = @company_id, company_name = @company_name,
          inventory_type_id = @inventory_type_id, inventory_type = @inventory_type,
          category_id = @category_id, category = @category,
          is_active = @is_active
        WHERE id = @id
        RETURNING $_cols
      '''),
      parameters: i.toMap(),
    );
    return StockItemModel.fromMap(r.first.toColumnMap());
  }

  Future<void> delete(int id) => _conn.execute(
        Sql.named('DELETE FROM stock_item WHERE id = @id'),
        parameters: {'id': id},
      );
}
