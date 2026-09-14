import 'package:postgres/postgres.dart';

import '../../../../config/database/database_connection.dart';
import '../model/company_model.dart';

const _columns = 'id, name, email, address, phone, opening_balance, is_active';

/// Talks to PostgreSQL for the Company feature.
class CompanyDataSource {
  const CompanyDataSource();

  /// Creates the `company` table if it is missing. A permission error
  /// (42501) is ignored so the app still works when the table was created
  /// by lib/features/company/data/sql/company.sql.
  Future<void> ensureSchema() async {
    try {
      await Database.instance.connection.execute('''
        CREATE TABLE IF NOT EXISTS company (
          id              SERIAL PRIMARY KEY,
          name            TEXT          NOT NULL,
          email           TEXT          NOT NULL DEFAULT '',
          address         TEXT          NOT NULL DEFAULT '',
          phone           TEXT          NOT NULL DEFAULT '',
          opening_balance NUMERIC(14,2) NOT NULL DEFAULT 0,
          is_active       BOOLEAN       NOT NULL DEFAULT TRUE,
          created_at      TIMESTAMPTZ   NOT NULL DEFAULT now()
        )
      ''');
      await Database.instance.connection.execute(
        'ALTER TABLE company ADD COLUMN IF NOT EXISTS '
        'balance_migrated BOOLEAN NOT NULL DEFAULT FALSE',
      );
    } on ServerException catch (e) {
      if (e.code != '42501') rethrow;
    }
    await _migrateHistoricalBalances();
  }

  /// One-time backfill for the 2026-09-13 switch to a live
  /// `company.opening_balance` (previously a static opening that purchase
  /// invoices/returns/payments never touched — see `PurchaseDataSource`,
  /// `PurchaseReturnDataSource`, `CompanyPaymentDataSource`). Folds every
  /// company's *pre-existing* purchase history into its opening balance
  /// exactly once (`balance_migrated` guards against re-running and
  /// double-counting); every purchase invoice/return/payment from here on
  /// keeps it live by mutating it directly. No-ops once already migrated, and
  /// swallows a missing `purchase_invoice` / `purchase_return` /
  /// `company_payment` table (nothing to backfill yet).
  Future<void> _migrateHistoricalBalances() async {
    try {
      await Database.instance.connection.execute('''
        UPDATE company c SET
          opening_balance = opening_balance
            + COALESCE((SELECT SUM(grand_total) FROM purchase_invoice WHERE company_id = c.id), 0)
            - COALESCE((SELECT SUM(amount_paid) FROM purchase_invoice WHERE company_id = c.id), 0)
            - COALESCE((SELECT SUM(grand_total) FROM purchase_return WHERE company_id = c.id), 0)
            - COALESCE((SELECT SUM(amount) FROM company_payment WHERE company_id = c.id), 0),
          balance_migrated = TRUE
        WHERE c.balance_migrated = FALSE
      ''');
    } on ServerException catch (e) {
      if (e.code != '42P01' && e.code != '42703' && e.code != '42501') rethrow;
    }
  }

  Future<List<CompanyModel>> fetchAll() async {
    final result = await Database.instance.connection.execute(
      'SELECT $_columns FROM company ORDER BY name',
    );
    return result.map((row) => CompanyModel.fromMap(row.toColumnMap())).toList();
  }

  Future<CompanyModel> insert(CompanyModel c) async {
    final result = await Database.instance.connection.execute(
      Sql.named('''
        INSERT INTO company (name, email, address, phone, opening_balance, is_active)
        VALUES (@name, @email, @address, @phone, @opening_balance, @is_active)
        RETURNING $_columns
      '''),
      parameters: _params(c),
    );
    return CompanyModel.fromMap(result.first.toColumnMap());
  }

  Future<CompanyModel> update(CompanyModel c) async {
    final result = await Database.instance.connection.execute(
      Sql.named('''
        UPDATE company SET
          name = @name, email = @email, address = @address, phone = @phone,
          opening_balance = @opening_balance, is_active = @is_active
        WHERE id = @id
        RETURNING $_columns
      '''),
      parameters: {..._params(c), 'id': c.id},
    );
    return CompanyModel.fromMap(result.first.toColumnMap());
  }

  Future<void> delete(int id) async {
    await Database.instance.connection.execute(
      Sql.named('DELETE FROM company WHERE id = @id'),
      parameters: {'id': id},
    );
  }

  Map<String, dynamic> _params(CompanyModel c) => {
        'name': c.name,
        'email': c.email,
        'address': c.address,
        'phone': c.phone,
        'opening_balance': c.openingBalance,
        'is_active': c.isActive,
      };
}
