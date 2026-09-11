import 'package:postgres/postgres.dart';

import '../../../../config/database/database_connection.dart';
import '../../../bank/data/datasource/bank_datasource.dart';
import '../../../bank/data/model/bank_head_model.dart';
import '../../../company/data/datasource/company_datasource.dart';
import '../model/company_payable_ref.dart';
import '../model/company_payment_model.dart';

const _cols = 'id, payment_no, payment_date, company_id, company_name, '
    'amount, bank_head_id, reference, narration';

/// Talks to PostgreSQL for the Company Payment feature — money paid out to a
/// company (supplier) against what the business owes them, outside of a
/// purchase invoice.
///
/// Mirrors the purchase invoice's own convention: a `bank_head_id` on the row
/// means the money was paid out of that bank account; `NULL` means cash.
class CompanyPaymentDataSource {
  const CompanyPaymentDataSource();

  Connection get _conn => Database.instance.connection;

  /// Creates the `company_payment` table if missing. A permission error
  /// (42501) is ignored so the app still works when the table was created by
  /// lib/features/company_payment/data/sql/company_payment.sql.
  Future<void> ensureSchema() async {
    await const CompanyDataSource().ensureSchema();
    await const BankDataSource().ensureSchema();

    try {
      await _conn.execute('''
        CREATE TABLE IF NOT EXISTS company_payment (
          id            SERIAL PRIMARY KEY,
          payment_no    TEXT          NOT NULL DEFAULT '',
          payment_date  DATE          NOT NULL DEFAULT CURRENT_DATE,
          company_id    INTEGER       NOT NULL REFERENCES company(id),
          company_name  TEXT          NOT NULL DEFAULT '',
          amount        NUMERIC(14,2) NOT NULL DEFAULT 0,
          bank_head_id  INTEGER,
          reference     TEXT          NOT NULL DEFAULT '',
          narration     TEXT          NOT NULL DEFAULT '',
          created_at    TIMESTAMPTZ   NOT NULL DEFAULT now()
        )
      ''');
      await _conn.execute(
        'CREATE INDEX IF NOT EXISTS idx_company_payment_company_id '
        'ON company_payment(company_id)',
      );
      await _conn.execute(
        'CREATE INDEX IF NOT EXISTS idx_company_payment_date '
        'ON company_payment(payment_date)',
      );
    } on ServerException catch (e) {
      if (e.code != '42501') rethrow;
    }
  }

  Future<List<CompanyPaymentModel>> fetchAll() async {
    final r = await _conn.execute(
      'SELECT $_cols FROM company_payment ORDER BY payment_date DESC, id DESC',
    );
    return r.map((row) => CompanyPaymentModel.fromMap(row.toColumnMap())).toList();
  }

  /// Active companies for the payment form's picker, with how much the
  /// business currently owes each one (opening + purchases - returns - what
  /// has already been paid). Falls back to just the opening balance if
  /// `purchase_invoice` / `purchase_return` / `company_payment` aren't there yet.
  Future<List<CompanyPayableRef>> fetchCompanies() async {
    try {
      final r = await _conn.execute('''
        SELECT c.id, c.name,
               c.opening_balance
                 + COALESCE(pi.total, 0)
                 - COALESCE(pr.total, 0)
                 - COALESCE(cp.total, 0) AS payable
        FROM company c
        LEFT JOIN (SELECT company_id, SUM(grand_total) AS total
                   FROM purchase_invoice GROUP BY company_id) pi ON pi.company_id = c.id
        LEFT JOIN (SELECT company_id, SUM(grand_total) AS total
                   FROM purchase_return GROUP BY company_id) pr ON pr.company_id = c.id
        LEFT JOIN (SELECT company_id, SUM(amount) AS total
                   FROM company_payment GROUP BY company_id) cp ON cp.company_id = c.id
        WHERE c.is_active = TRUE
        ORDER BY c.name
      ''');
      return r.map((row) => CompanyPayableRef.fromMap(row.toColumnMap())).toList();
    } on ServerException {
      final r = await _conn.execute(
        'SELECT id, name, opening_balance AS payable FROM company '
        'WHERE is_active = TRUE ORDER BY name',
      );
      return r.map((row) => CompanyPayableRef.fromMap(row.toColumnMap())).toList();
    }
  }

  /// Active bank accounts for the optional "pay from bank" picker.
  Future<List<BankHeadModel>> fetchBanks() async {
    final r = await _conn.execute(
      'SELECT id, title, bank_name, account_number, opening_balance, is_active '
      'FROM bank_head WHERE is_active = TRUE ORDER BY title',
    );
    return r.map((row) => BankHeadModel.fromMap(row.toColumnMap())).toList();
  }

  Future<CompanyPaymentModel> insert(CompanyPaymentModel p) {
    return _conn.runTx((s) async {
      final r = await s.execute(
        Sql.named('''
          INSERT INTO company_payment
            (payment_no, payment_date, company_id, company_name, amount,
             bank_head_id, reference, narration)
          VALUES
            (@payment_no, @payment_date, @company_id, @company_name, @amount,
             @bank_head_id, @reference, @narration)
          RETURNING $_cols
        '''),
        parameters: p.toMap()..remove('id'),
      );
      var header = r.first.toColumnMap();
      final id = header['id'] as int;
      if (((header['payment_no'] as String?) ?? '').isEmpty) {
        final n = await s.execute(
          Sql.named("UPDATE company_payment "
              "SET payment_no = 'SP-' || lpad(@id::text, 6, '0') "
              "WHERE id = @id RETURNING $_cols"),
          parameters: {'id': id},
        );
        header = n.first.toColumnMap();
      }
      final description = 'Payment ${(header['payment_no'] as String?) ?? ''}'
          '${p.companyName.isEmpty ? '' : ' — ${p.companyName}'}';
      if (p.bankHeadId != null) {
        await _postBankWithdraw(
          s,
          bankHeadId: p.bankHeadId,
          amount: p.amount,
          date: p.date,
          description: description,
        );
      } else {
        await _postCashOut(s, amount: p.amount, date: p.date, description: description);
      }
      return CompanyPaymentModel.fromMap(header);
    });
  }

  Future<CompanyPaymentModel> update(CompanyPaymentModel p) async {
    final r = await _conn.execute(
      Sql.named('''
        UPDATE company_payment SET
          payment_no = @payment_no, payment_date = @payment_date,
          company_id = @company_id, company_name = @company_name,
          amount = @amount, bank_head_id = @bank_head_id,
          reference = @reference, narration = @narration
        WHERE id = @id
        RETURNING $_cols
      '''),
      parameters: p.toMap(),
    );
    return CompanyPaymentModel.fromMap(r.first.toColumnMap());
  }

  Future<void> delete(int id) => _conn.execute(
        Sql.named('DELETE FROM company_payment WHERE id = @id'),
        parameters: {'id': id},
      );

  /// Posts a `bank_entry` withdrawal for [amount] against [bankHeadId].
  Future<void> _postBankWithdraw(
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
        VALUES (@h, @d, 'withdraw', @a, @desc)
      '''),
      parameters: {
        'h': bankHeadId,
        'd': date,
        'a': amount,
        'desc': description.trim(),
      },
    );
  }

  /// Posts a `cash_entry` cash-out for [amount] (money paid out of the drawer).
  Future<void> _postCashOut(
    Session s, {
    required double amount,
    required DateTime date,
    required String description,
  }) async {
    if (amount == 0) return;
    await s.execute(
      Sql.named('''
        INSERT INTO cash_entry (entry_date, type, amount, category, description)
        VALUES (@d, 'out', @a, 'Company payment', @desc)
      '''),
      parameters: {'d': date, 'a': amount, 'desc': description.trim()},
    );
  }
}
