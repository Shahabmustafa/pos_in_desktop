import 'package:postgres/postgres.dart';

import '../../../../config/database/database_connection.dart';
import '../model/customer_model.dart';

const _columns = 'id, name, email, address, phone, opening_balance, is_active';

/// Name of the default "walk-in" customer used for counter sales that are not
/// tied to a named account.
const String kWalkInCustomerName = 'Walk-in Customer';

/// Talks to PostgreSQL for the Customer feature.
class CustomerDataSource {
  const CustomerDataSource();

  /// Makes sure a single active [kWalkInCustomerName] row exists, so sale
  /// screens can default to it. Safe to call repeatedly.
  Future<void> ensureWalkInCustomer() async {
    try {
      await Database.instance.connection.execute(
        Sql.named('''
          INSERT INTO customer (name)
          SELECT @name
          WHERE NOT EXISTS (
            SELECT 1 FROM customer WHERE lower(name) = lower(@name)
          )
        '''),
        parameters: {'name': kWalkInCustomerName},
      );
    } on ServerException catch (e) {
      if (e.code != '42501') rethrow;
    }
  }

  /// Creates the `customer` table if it is missing. A permission error
  /// (42501) is ignored so the app still works when the table was created
  /// by lib/features/customer/data/sql/customer.sql.
  Future<void> ensureSchema() async {
    try {
      await Database.instance.connection.execute('''
        CREATE TABLE IF NOT EXISTS customer (
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
    } on ServerException catch (e) {
      if (e.code != '42501') rethrow;
    }
  }

  Future<List<CustomerModel>> fetchAll() async {
    final result = await Database.instance.connection.execute(
      'SELECT $_columns FROM customer ORDER BY name',
    );
    return result.map((row) => CustomerModel.fromMap(row.toColumnMap())).toList();
  }

  Future<CustomerModel> insert(CustomerModel c) async {
    final result = await Database.instance.connection.execute(
      Sql.named('''
        INSERT INTO customer (name, email, address, phone, opening_balance, is_active)
        VALUES (@name, @email, @address, @phone, @opening_balance, @is_active)
        RETURNING $_columns
      '''),
      parameters: _params(c),
    );
    return CustomerModel.fromMap(result.first.toColumnMap());
  }

  Future<CustomerModel> update(CustomerModel c) async {
    final result = await Database.instance.connection.execute(
      Sql.named('''
        UPDATE customer SET
          name = @name, email = @email, address = @address, phone = @phone,
          opening_balance = @opening_balance, is_active = @is_active
        WHERE id = @id
        RETURNING $_columns
      '''),
      parameters: {..._params(c), 'id': c.id},
    );
    return CustomerModel.fromMap(result.first.toColumnMap());
  }

  Future<void> delete(int id) async {
    await Database.instance.connection.execute(
      Sql.named('DELETE FROM customer WHERE id = @id'),
      parameters: {'id': id},
    );
  }

  Map<String, dynamic> _params(CustomerModel c) => {
        'name': c.name,
        'email': c.email,
        'address': c.address,
        'phone': c.phone,
        'opening_balance': c.openingBalance,
        'is_active': c.isActive,
      };
}
