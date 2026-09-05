import 'package:postgres/postgres.dart';

import '../../../../config/database/database_connection.dart';
import '../model/category_model.dart';
import '../model/inventory_type_model.dart';

const _cols = 'id, name, description, is_active';

/// Seeded into `inventory_type` on first run so the product form has sensible
/// options even before anyone opens the catalog screen.
const _defaultInventoryTypes = [
  'Finished Goods',
  'Raw Material',
  'Packaging',
  'Consumable',
  'Service',
];

/// Talks to PostgreSQL for the Product Catalog feature (categories and
/// inventory types). Each lives in its own table.
class ProductCatalogDataSource {
  const ProductCatalogDataSource();

  Connection get _conn => Database.instance.connection;

  /// Creates the `product_category` and `inventory_type` tables if missing.
  /// A permission error (42501) is ignored so the app still works when the
  /// tables were created by
  /// lib/features/product_catalog/data/sql/product_catalog.sql.
  Future<void> ensureSchema() async {
    try {
      await _conn.execute('''
        CREATE TABLE IF NOT EXISTS product_category (
          id          SERIAL PRIMARY KEY,
          name        TEXT        NOT NULL UNIQUE,
          description TEXT        NOT NULL DEFAULT '',
          is_active   BOOLEAN     NOT NULL DEFAULT TRUE,
          created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
        )
      ''');
      await _conn.execute('''
        CREATE TABLE IF NOT EXISTS inventory_type (
          id          SERIAL PRIMARY KEY,
          name        TEXT        NOT NULL UNIQUE,
          description TEXT        NOT NULL DEFAULT '',
          is_active   BOOLEAN     NOT NULL DEFAULT TRUE,
          created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
        )
      ''');

      // Seed the standard inventory types once (only when the table is empty,
      // so a type the user later deletes does not come back).
      final existing = await _conn.execute('SELECT COUNT(*) FROM inventory_type');
      if ((existing.first.first as int) == 0) {
        for (final name in _defaultInventoryTypes) {
          await _conn.execute(
            Sql.named('INSERT INTO inventory_type (name) VALUES (@name) '
                'ON CONFLICT (name) DO NOTHING'),
            parameters: {'name': name},
          );
        }
      }
    } on ServerException catch (e) {
      if (e.code != '42501') rethrow;
    }
  }

  // --- Categories ---------------------------------------------------------

  Future<List<CategoryModel>> fetchCategories() async {
    final r = await _conn
        .execute('SELECT $_cols FROM product_category ORDER BY name');
    return r.map((row) => CategoryModel.fromMap(row.toColumnMap())).toList();
  }

  Future<CategoryModel> insertCategory(CategoryModel c) async {
    final r = await _conn.execute(
      Sql.named('''
        INSERT INTO product_category (name, description, is_active)
        VALUES (@name, @description, @is_active)
        RETURNING $_cols
      '''),
      parameters: c.toMap()..remove('id'),
    );
    return CategoryModel.fromMap(r.first.toColumnMap());
  }

  Future<CategoryModel> updateCategory(CategoryModel c) async {
    final r = await _conn.execute(
      Sql.named('''
        UPDATE product_category SET
          name = @name, description = @description, is_active = @is_active
        WHERE id = @id
        RETURNING $_cols
      '''),
      parameters: c.toMap(),
    );
    return CategoryModel.fromMap(r.first.toColumnMap());
  }

  Future<void> deleteCategory(int id) => _conn.execute(
        Sql.named('DELETE FROM product_category WHERE id = @id'),
        parameters: {'id': id},
      );

  // --- Inventory types ---------------------------------------------------

  Future<List<InventoryTypeModel>> fetchInventoryTypes() async {
    final r = await _conn
        .execute('SELECT $_cols FROM inventory_type ORDER BY name');
    return r.map((row) => InventoryTypeModel.fromMap(row.toColumnMap())).toList();
  }

  Future<InventoryTypeModel> insertInventoryType(InventoryTypeModel t) async {
    final r = await _conn.execute(
      Sql.named('''
        INSERT INTO inventory_type (name, description, is_active)
        VALUES (@name, @description, @is_active)
        RETURNING $_cols
      '''),
      parameters: t.toMap()..remove('id'),
    );
    return InventoryTypeModel.fromMap(r.first.toColumnMap());
  }

  Future<InventoryTypeModel> updateInventoryType(InventoryTypeModel t) async {
    final r = await _conn.execute(
      Sql.named('''
        UPDATE inventory_type SET
          name = @name, description = @description, is_active = @is_active
        WHERE id = @id
        RETURNING $_cols
      '''),
      parameters: t.toMap(),
    );
    return InventoryTypeModel.fromMap(r.first.toColumnMap());
  }

  Future<void> deleteInventoryType(int id) => _conn.execute(
        Sql.named('DELETE FROM inventory_type WHERE id = @id'),
        parameters: {'id': id},
      );
}
