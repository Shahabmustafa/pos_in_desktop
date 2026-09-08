import 'package:postgres/postgres.dart';

import '../../../../config/database/database_connection.dart';
import '../model/expense_entry_model.dart';
import '../model/expense_head_model.dart';

const _headCols = 'id, name, description, is_active';

/// Talks to PostgreSQL for the Expense feature (heads + entries).
class ExpenseDataSource {
  const ExpenseDataSource();

  Connection get _conn => Database.instance.connection;

  /// Creates the `expense_head` and `expense_entry` tables if missing.
  Future<void> ensureSchema() async {
    try {
      await _conn.execute('''
        CREATE TABLE IF NOT EXISTS expense_head (
          id          SERIAL PRIMARY KEY,
          name        TEXT        NOT NULL,
          description TEXT        NOT NULL DEFAULT '',
          is_active   BOOLEAN     NOT NULL DEFAULT TRUE,
          created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
        )
      ''');
      await _conn.execute('''
        CREATE TABLE IF NOT EXISTS expense_entry (
          id              SERIAL PRIMARY KEY,
          expense_head_id INTEGER       NOT NULL REFERENCES expense_head(id) ON DELETE CASCADE,
          entry_date      DATE          NOT NULL DEFAULT CURRENT_DATE,
          amount          NUMERIC(14,2) NOT NULL DEFAULT 0,
          payment_mode    TEXT          NOT NULL DEFAULT 'cash',
          description     TEXT          NOT NULL DEFAULT '',
          created_at      TIMESTAMPTZ   NOT NULL DEFAULT now()
        )
      ''');
    } on ServerException catch (e) {
      if (e.code != '42501') rethrow;
    }
  }

  // ---- Heads --------------------------------------------------------------

  Future<List<ExpenseHeadModel>> fetchHeads() async {
    final r =
        await _conn.execute('SELECT $_headCols FROM expense_head ORDER BY name');
    return r.map((row) => ExpenseHeadModel.fromMap(row.toColumnMap())).toList();
  }

  Future<ExpenseHeadModel> insertHead(ExpenseHeadModel h) async {
    final r = await _conn.execute(
      Sql.named('''
        INSERT INTO expense_head (name, description, is_active)
        VALUES (@name, @description, @is_active)
        RETURNING $_headCols
      '''),
      parameters: h.toMap()..remove('id'),
    );
    return ExpenseHeadModel.fromMap(r.first.toColumnMap());
  }

  Future<ExpenseHeadModel> updateHead(ExpenseHeadModel h) async {
    final r = await _conn.execute(
      Sql.named('''
        UPDATE expense_head SET
          name = @name, description = @description, is_active = @is_active
        WHERE id = @id
        RETURNING $_headCols
      '''),
      parameters: h.toMap(),
    );
    return ExpenseHeadModel.fromMap(r.first.toColumnMap());
  }

  Future<void> deleteHead(int id) => _conn.execute(
        Sql.named('DELETE FROM expense_head WHERE id = @id'),
        parameters: {'id': id},
      );

  /// Total spent per head id.
  Future<Map<int, double>> headTotals() async {
    final r = await _conn.execute('''
      SELECT h.id, COALESCE(SUM(e.amount), 0) AS total
      FROM expense_head h
      LEFT JOIN expense_entry e ON e.expense_head_id = h.id
      GROUP BY h.id
    ''');
    final out = <int, double>{};
    for (final row in r) {
      final m = row.toColumnMap();
      final raw = m['total'];
      out[m['id'] as int] =
          raw is num ? raw.toDouble() : double.tryParse(raw.toString()) ?? 0;
    }
    return out;
  }

  // ---- Entries ----------------------------------------------------------

  Future<List<ExpenseEntryModel>> fetchEntries({int? headId}) async {
    final where = headId == null ? '' : 'WHERE e.expense_head_id = @head_id';
    final r = await _conn.execute(
      Sql.named('''
        SELECT e.id, e.expense_head_id, e.entry_date, e.amount, e.payment_mode,
               e.description, h.name AS expense_head_name
        FROM expense_entry e
        JOIN expense_head h ON h.id = e.expense_head_id
        $where
        ORDER BY e.entry_date DESC, e.id DESC
      '''),
      parameters: headId == null ? const {} : {'head_id': headId},
    );
    return r.map((row) => ExpenseEntryModel.fromMap(row.toColumnMap())).toList();
  }

  Future<void> insertEntry(ExpenseEntryModel e) => _conn.execute(
        Sql.named('''
          INSERT INTO expense_entry (expense_head_id, entry_date, amount, payment_mode, description)
          VALUES (@expense_head_id, @entry_date, @amount, @payment_mode, @description)
        '''),
        parameters: e.toMap()..remove('id'),
      );

  Future<void> updateEntry(ExpenseEntryModel e) => _conn.execute(
        Sql.named('''
          UPDATE expense_entry SET
            expense_head_id = @expense_head_id, entry_date = @entry_date,
            amount = @amount, payment_mode = @payment_mode, description = @description
          WHERE id = @id
        '''),
        parameters: e.toMap(),
      );

  Future<void> deleteEntry(int id) => _conn.execute(
        Sql.named('DELETE FROM expense_entry WHERE id = @id'),
        parameters: {'id': id},
      );
}
