import 'package:postgres/postgres.dart';

import '../../../../config/database/database_connection.dart';
import '../model/cash_register_model.dart';

/// Talks to PostgreSQL for the Cash Register feature.
///
/// `cash_account` (one row) and `cash_entry` (manual movements) are stored.
/// The cash book is assembled on read from those plus the cash-affecting rows
/// of `sale_invoice` / `sale_return` / `expense_entry` / `voucher`. A source
/// table that does not exist yet just drops out (same as `ReportsDataSource`).
class CashRegisterDataSource {
  const CashRegisterDataSource();

  Connection get _conn => Database.instance.connection;

  /// Creates `cash_account` / `cash_entry` if missing and guarantees the single
  /// cash-account row exists.
  Future<void> ensureSchema() async {
    try {
      await _conn.execute('''
        CREATE TABLE IF NOT EXISTS cash_account (
          id              SERIAL PRIMARY KEY,
          title           TEXT          NOT NULL DEFAULT 'Cash in Hand',
          opening_balance NUMERIC(14,2) NOT NULL DEFAULT 0,
          opening_date    DATE          NOT NULL DEFAULT CURRENT_DATE,
          created_at      TIMESTAMPTZ   NOT NULL DEFAULT now()
        )
      ''');
      await _conn.execute('''
        CREATE TABLE IF NOT EXISTS cash_entry (
          id          SERIAL PRIMARY KEY,
          entry_date  DATE          NOT NULL DEFAULT CURRENT_DATE,
          type        TEXT          NOT NULL DEFAULT 'out',
          amount      NUMERIC(14,2) NOT NULL DEFAULT 0,
          category    TEXT          NOT NULL DEFAULT '',
          description TEXT          NOT NULL DEFAULT '',
          created_at  TIMESTAMPTZ   NOT NULL DEFAULT now()
        )
      ''');
      await _conn.execute('''
        INSERT INTO cash_account (title)
        SELECT 'Cash in Hand'
        WHERE NOT EXISTS (SELECT 1 FROM cash_account)
      ''');
    } on ServerException catch (e) {
      if (e.code != '42501') rethrow;
    }
  }

  Future<CashAccount> account() async {
    final rows = await _guard(
      () => _conn.execute(
        'SELECT id, title, opening_balance, opening_date FROM cash_account '
        'ORDER BY id LIMIT 1',
      ),
      null,
    );
    if (rows == null || rows.isEmpty) return CashAccount();
    return CashAccount.fromMap(rows.first.toColumnMap());
  }

  Future<CashAccount> saveAccount(CashAccount a) async {
    final rows = await _conn.execute(
      Sql.named('''
        UPDATE cash_account SET
          title = @title, opening_balance = @opening_balance,
          opening_date = @opening_date
        WHERE id = @id
        RETURNING id, title, opening_balance, opening_date
      '''),
      parameters: {
        'id': a.id,
        'title': a.title,
        'opening_balance': a.openingBalance,
        'opening_date': a.openingDate,
      },
    );
    return CashAccount.fromMap(rows.first.toColumnMap());
  }

  // ── Manual entries ─────────────────────────────────────────────────
  Future<List<CashEntry>> entries() async {
    final rows = await _guard(
      () => _conn.execute(
        'SELECT id, entry_date, type, amount, category, description '
        'FROM cash_entry ORDER BY entry_date DESC, id DESC',
      ),
      null,
    );
    if (rows == null) return const [];
    return rows.map((r) => CashEntry.fromMap(r.toColumnMap())).toList();
  }

  Future<CashEntry> insertEntry(CashEntry e) async {
    final rows = await _conn.execute(
      Sql.named('''
        INSERT INTO cash_entry (entry_date, type, amount, category, description)
        VALUES (@entry_date, @type, @amount, @category, @description)
        RETURNING id, entry_date, type, amount, category, description
      '''),
      parameters: e.toMap()..remove('id'),
    );
    return CashEntry.fromMap(rows.first.toColumnMap());
  }

  Future<CashEntry> updateEntry(CashEntry e) async {
    final rows = await _conn.execute(
      Sql.named('''
        UPDATE cash_entry SET
          entry_date = @entry_date, type = @type, amount = @amount,
          category = @category, description = @description
        WHERE id = @id
        RETURNING id, entry_date, type, amount, category, description
      '''),
      parameters: e.toMap(),
    );
    return CashEntry.fromMap(rows.first.toColumnMap());
  }

  Future<void> deleteEntry(int id) => _conn.execute(
        Sql.named('DELETE FROM cash_entry WHERE id = @id'),
        parameters: {'id': id},
      );

  // ── Cash book ──────────────────────────────────────────────────────
  Future<CashBook> cashBook(DateTime from, DateTime to) async {
    final acc = await account();
    final moves = <CashMovement>[];

    // Cash sales — money into the drawer at billing (bank_head_id NULL means it
    // did not go to a bank account).
    await _collect(moves, '''
      SELECT invoice_date AS d, id AS ord, invoice_no AS doc, customer_name AS party,
             amount_received AS amt
      FROM sale_invoice
      WHERE bank_head_id IS NULL AND amount_received <> 0
    ''', (m) => CashMovement(
          date: _dt(m['d']),
          type: 'Sale',
          category: 'Cash sale',
          detail: _combine(m['doc'], m['party']),
          inAmount: _d(m['amt']),
          outAmount: 0,
          sortKey: (m['ord'] as int) * 10,
        ));

    // Cash refunds on a sale return.
    await _collect(moves, '''
      SELECT return_date AS d, id AS ord, invoice_no AS doc, customer_name AS party,
             amount_paid AS amt
      FROM sale_return
      WHERE bank_head_id IS NULL AND amount_paid <> 0
    ''', (m) => CashMovement(
          date: _dt(m['d']),
          type: 'Refund',
          category: 'Sale return',
          detail: _combine(m['doc'], m['party']),
          inAmount: 0,
          outAmount: _d(m['amt']),
          sortKey: (m['ord'] as int) * 10,
        ));

    // Cash expenses.
    await _collect(moves, '''
      SELECT ee.entry_date AS d, ee.id AS ord, eh.name AS head, ee.description AS descr,
             ee.amount AS amt
      FROM expense_entry ee
      JOIN expense_head eh ON eh.id = ee.expense_head_id
      WHERE lower(ee.payment_mode) = 'cash'
    ''', (m) => CashMovement(
          date: _dt(m['d']),
          type: 'Expense',
          category: _text(m['head']),
          detail: _text(m['descr']),
          inAmount: 0,
          outAmount: _d(m['amt']),
          sortKey: (m['ord'] as int) * 10,
        ));

    // Cash vouchers — receipt in, payment out.
    await _collect(moves, '''
      SELECT voucher_date AS d, id AS ord, voucher_no AS doc, type AS vt,
             party, narration, amount AS amt
      FROM voucher
      WHERE lower(payment_mode) = 'cash' AND lower(type) IN ('receipt', 'payment')
    ''', (m) {
      final isReceipt = (m['vt'] as String?)?.toLowerCase() == 'receipt';
      return CashMovement(
        date: _dt(m['d']),
        type: isReceipt ? 'Receipt' : 'Payment',
        category: _text(m['party']),
        detail: _combine(m['doc'], m['narration']),
        inAmount: isReceipt ? _d(m['amt']) : 0,
        outAmount: isReceipt ? 0 : _d(m['amt']),
        sortKey: (m['ord'] as int) * 10,
      );
    });

    // Hand-entered movements.
    for (final e in await entries()) {
      moves.add(CashMovement(
        date: e.date,
        type: e.direction.label,
        category: e.category.isEmpty ? '—' : e.category,
        detail: e.description,
        inAmount: e.direction == CashDirection.cashIn ? e.amount : 0,
        outAmount: e.direction == CashDirection.cashOut ? e.amount : 0,
        sortKey: (e.id ?? 0) * 10 + 5,
        manualId: e.id,
      ));
    }

    return CashBook.build(
      title: acc.title,
      openingFloat: acc.openingBalance,
      moves: moves,
      from: from,
      to: to,
      asOf: DateTime.now(),
    );
  }

  // ── helpers ────────────────────────────────────────────────────────
  Future<void> _collect(
    List<CashMovement> into,
    String sql,
    CashMovement Function(Map<String, dynamic> row) map,
  ) async {
    final rows = await _guard(() => _conn.execute(sql), null);
    if (rows == null) return;
    for (final row in rows) {
      into.add(map(row.toColumnMap()));
    }
  }

  Future<T?> _guard<T>(Future<T> Function() run, T? fallback) async {
    try {
      return await run();
    } on ServerException catch (e) {
      if (e.code == '42P01' || e.code == '42703' || e.code == '42501') {
        return fallback;
      }
      rethrow;
    }
  }

  static String _combine(Object? a, Object? b) {
    final x = _text(a);
    final y = _text(b);
    if (x.isEmpty) return y;
    if (y.isEmpty) return x;
    return '$x · $y';
  }

  static String _text(Object? v) => (v as String?)?.trim() ?? '';

  static DateTime _dt(Object? v) {
    if (v is DateTime) return v;
    return DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
  }

  static double _d(Object? v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}
