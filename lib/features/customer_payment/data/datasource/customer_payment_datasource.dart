import 'package:postgres/postgres.dart';

import '../../../../config/database/database_connection.dart';
import '../../../bank/data/datasource/bank_datasource.dart';
import '../../../bank/data/model/bank_head_model.dart';
import '../../../customer/data/datasource/customer_datasource.dart';
import '../../../sale_invoice/data/model/sale_invoice_refs.dart';
import '../model/customer_payment_model.dart';

const _cols = 'id, payment_no, payment_date, customer_id, customer_name, '
    'amount, bank_head_id, reference, narration';

/// Talks to PostgreSQL for the Customer Payment feature — money collected
/// from a customer against their standing balance, outside of a sale invoice.
///
/// Mirrors the sale invoice's own convention: a `bank_head_id` on the row
/// means the money was deposited into that bank account; `NULL` means cash.
class CustomerPaymentDataSource {
  const CustomerPaymentDataSource();

  Connection get _conn => Database.instance.connection;

  /// Creates the `customer_payment` table if missing. A permission error
  /// (42501) is ignored so the app still works when the table was created by
  /// lib/features/customer_payment/data/sql/customer_payment.sql.
  Future<void> ensureSchema() async {
    await const CustomerDataSource().ensureSchema();
    await const BankDataSource().ensureSchema();

    try {
      await _conn.execute('''
        CREATE TABLE IF NOT EXISTS customer_payment (
          id            SERIAL PRIMARY KEY,
          payment_no    TEXT          NOT NULL DEFAULT '',
          payment_date  DATE          NOT NULL DEFAULT CURRENT_DATE,
          customer_id   INTEGER       NOT NULL REFERENCES customer(id),
          customer_name TEXT          NOT NULL DEFAULT '',
          amount        NUMERIC(14,2) NOT NULL DEFAULT 0,
          bank_head_id  INTEGER,
          reference     TEXT          NOT NULL DEFAULT '',
          narration     TEXT          NOT NULL DEFAULT '',
          created_at    TIMESTAMPTZ   NOT NULL DEFAULT now()
        )
      ''');
      await _conn.execute(
        'CREATE INDEX IF NOT EXISTS idx_customer_payment_customer_id '
        'ON customer_payment(customer_id)',
      );
      await _conn.execute(
        'CREATE INDEX IF NOT EXISTS idx_customer_payment_date '
        'ON customer_payment(payment_date)',
      );
    } on ServerException catch (e) {
      if (e.code != '42501') rethrow;
    }
  }

  Future<List<CustomerPaymentModel>> fetchAll() async {
    final r = await _conn.execute(
      'SELECT $_cols FROM customer_payment ORDER BY payment_date DESC, id DESC',
    );
    return r.map((row) => CustomerPaymentModel.fromMap(row.toColumnMap())).toList();
  }

  /// Active customers for the payment form's picker, with their current
  /// outstanding balance.
  Future<List<CustomerRef>> fetchCustomers() async {
    final r = await _conn.execute(
      'SELECT id, name, opening_balance FROM customer '
      'WHERE is_active = TRUE ORDER BY name',
    );
    return r.map((row) => CustomerRef.fromMap(row.toColumnMap())).toList();
  }

  /// Active bank accounts for the optional "deposit to bank" picker.
  Future<List<BankHeadModel>> fetchBanks() async {
    final r = await _conn.execute(
      'SELECT id, title, bank_name, account_number, opening_balance, is_active '
      'FROM bank_head WHERE is_active = TRUE ORDER BY title',
    );
    return r.map((row) => BankHeadModel.fromMap(row.toColumnMap())).toList();
  }

  Future<CustomerPaymentModel> insert(CustomerPaymentModel p) {
    return _conn.runTx((s) async {
      final r = await s.execute(
        Sql.named('''
          INSERT INTO customer_payment
            (payment_no, payment_date, customer_id, customer_name, amount,
             bank_head_id, reference, narration)
          VALUES
            (@payment_no, @payment_date, @customer_id, @customer_name, @amount,
             @bank_head_id, @reference, @narration)
          RETURNING $_cols
        '''),
        parameters: p.toMap()..remove('id'),
      );
      var header = r.first.toColumnMap();
      final id = header['id'] as int;
      if (((header['payment_no'] as String?) ?? '').isEmpty) {
        final n = await s.execute(
          Sql.named("UPDATE customer_payment "
              "SET payment_no = 'CP-' || lpad(@id::text, 6, '0') "
              "WHERE id = @id RETURNING $_cols"),
          parameters: {'id': id},
        );
        header = n.first.toColumnMap();
      }
      // Money received lowers what the customer still owes.
      await _adjustCustomerBalance(s, p.customerId, -p.amount);
      if (p.bankHeadId != null) {
        await _postBankDeposit(
          s,
          bankHeadId: p.bankHeadId,
          amount: p.amount,
          date: p.date,
          description: 'Payment ${(header['payment_no'] as String?) ?? ''}'
              '${p.customerName.isEmpty ? '' : ' — ${p.customerName}'}',
        );
      } else {
        await _postCashIn(
          s,
          amount: p.amount,
          date: p.date,
          description: 'Payment ${(header['payment_no'] as String?) ?? ''}'
              '${p.customerName.isEmpty ? '' : ' — ${p.customerName}'}',
        );
      }
      return CustomerPaymentModel.fromMap(header);
    });
  }

  Future<CustomerPaymentModel> update(CustomerPaymentModel p) {
    return _conn.runTx((s) async {
      // Undo the balance effect the previous version of this payment had.
      final prev = await s.execute(
        Sql.named('SELECT customer_id, amount FROM customer_payment WHERE id = @id'),
        parameters: {'id': p.id},
      );
      if (prev.isNotEmpty) {
        final m = prev.first.toColumnMap();
        await _adjustCustomerBalance(
            s, m['customer_id'] as int?, _num(m['amount']));
      }

      final r = await s.execute(
        Sql.named('''
          UPDATE customer_payment SET
            payment_no = @payment_no, payment_date = @payment_date,
            customer_id = @customer_id, customer_name = @customer_name,
            amount = @amount, bank_head_id = @bank_head_id,
            reference = @reference, narration = @narration
          WHERE id = @id
          RETURNING $_cols
        '''),
        parameters: p.toMap(),
      );
      await _adjustCustomerBalance(s, p.customerId, -p.amount);
      return CustomerPaymentModel.fromMap(r.first.toColumnMap());
    });
  }

  Future<void> delete(int id) {
    return _conn.runTx((s) async {
      final prev = await s.execute(
        Sql.named('SELECT customer_id, amount FROM customer_payment WHERE id = @id'),
        parameters: {'id': id},
      );
      if (prev.isNotEmpty) {
        final m = prev.first.toColumnMap();
        await _adjustCustomerBalance(
            s, m['customer_id'] as int?, _num(m['amount']));
      }
      await s.execute(
        Sql.named('DELETE FROM customer_payment WHERE id = @id'),
        parameters: {'id': id},
      );
    });
  }

  static double _num(Object? v) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? 0;
  }

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

  /// Posts a `bank_entry` deposit for [amount] against [bankHeadId].
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

  /// Posts a `cash_entry` cash-in for [amount] (money received into the drawer).
  Future<void> _postCashIn(
    Session s, {
    required double amount,
    required DateTime date,
    required String description,
  }) async {
    if (amount == 0) return;
    await s.execute(
      Sql.named('''
        INSERT INTO cash_entry (entry_date, type, amount, category, description)
        VALUES (@d, 'in', @a, 'Customer payment', @desc)
      '''),
      parameters: {'d': date, 'a': amount, 'desc': description.trim()},
    );
  }
}
