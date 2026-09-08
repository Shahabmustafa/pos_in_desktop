import 'package:postgres/postgres.dart';

import '../../../../config/database/database_connection.dart';
import '../model/bank_entry_model.dart';
import '../model/bank_head_model.dart';

const _headCols = 'id, title, bank_name, account_number, opening_balance, is_active';

/// Talks to PostgreSQL for the Bank feature (heads + entries).
class BankDataSource {
  const BankDataSource();

  Connection get _conn => Database.instance.connection;

  /// Creates the `bank_head` and `bank_entry` tables if missing.
  Future<void> ensureSchema() async {
    try {
      await _conn.execute('''
        CREATE TABLE IF NOT EXISTS bank_head (
          id              SERIAL PRIMARY KEY,
          title           TEXT          NOT NULL,
          bank_name       TEXT          NOT NULL DEFAULT '',
          account_number  TEXT          NOT NULL DEFAULT '',
          opening_balance NUMERIC(14,2) NOT NULL DEFAULT 0,
          is_active       BOOLEAN       NOT NULL DEFAULT TRUE,
          created_at      TIMESTAMPTZ   NOT NULL DEFAULT now()
        )
      ''');
      await _conn.execute('''
        CREATE TABLE IF NOT EXISTS bank_entry (
          id           SERIAL PRIMARY KEY,
          bank_head_id INTEGER       NOT NULL REFERENCES bank_head(id) ON DELETE CASCADE,
          entry_date   DATE          NOT NULL DEFAULT CURRENT_DATE,
          type         TEXT          NOT NULL DEFAULT 'deposit',
          amount       NUMERIC(14,2) NOT NULL DEFAULT 0,
          description  TEXT          NOT NULL DEFAULT '',
          created_at   TIMESTAMPTZ   NOT NULL DEFAULT now()
        )
      ''');
    } on ServerException catch (e) {
      if (e.code != '42501') rethrow;
    }
  }

  // ---- Heads --------------------------------------------------------------

  Future<List<BankHeadModel>> fetchHeads() async {
    final r = await _conn.execute('SELECT $_headCols FROM bank_head ORDER BY title');
    return r.map((row) => BankHeadModel.fromMap(row.toColumnMap())).toList();
  }

  Future<BankHeadModel> insertHead(BankHeadModel h) async {
    final r = await _conn.execute(
      Sql.named('''
        INSERT INTO bank_head (title, bank_name, account_number, opening_balance, is_active)
        VALUES (@title, @bank_name, @account_number, @opening_balance, @is_active)
        RETURNING $_headCols
      '''),
      parameters: h.toMap()..remove('id'),
    );
    return BankHeadModel.fromMap(r.first.toColumnMap());
  }

  Future<BankHeadModel> updateHead(BankHeadModel h) async {
    final r = await _conn.execute(
      Sql.named('''
        UPDATE bank_head SET
          title = @title, bank_name = @bank_name, account_number = @account_number,
          opening_balance = @opening_balance, is_active = @is_active
        WHERE id = @id
        RETURNING $_headCols
      '''),
      parameters: h.toMap(),
    );
    return BankHeadModel.fromMap(r.first.toColumnMap());
  }

  Future<void> deleteHead(int id) => _conn.execute(
        Sql.named('DELETE FROM bank_head WHERE id = @id'),
        parameters: {'id': id},
      );

  /// Current balance per head id: opening + sum(signed entries).
  Future<Map<int, double>> headBalances() async {
    final r = await _conn.execute('''
      SELECT h.id,
             h.opening_balance
             + COALESCE(SUM(CASE WHEN e.type = 'withdraw' THEN -e.amount ELSE e.amount END), 0)
               AS balance
      FROM bank_head h
      LEFT JOIN bank_entry e ON e.bank_head_id = h.id
      GROUP BY h.id, h.opening_balance
    ''');
    final out = <int, double>{};
    for (final row in r) {
      final m = row.toColumnMap();
      final raw = m['balance'];
      out[m['id'] as int] =
          raw is num ? raw.toDouble() : double.tryParse(raw.toString()) ?? 0;
    }
    return out;
  }

  // ---- Entries ----------------------------------------------------------

  Future<List<BankEntryModel>> fetchEntries({int? headId}) async {
    final where = headId == null ? '' : 'WHERE e.bank_head_id = @head_id';
    final r = await _conn.execute(
      Sql.named('''
        SELECT e.id, e.bank_head_id, e.entry_date, e.type, e.amount, e.description,
               h.title AS bank_head_title
        FROM bank_entry e
        JOIN bank_head h ON h.id = e.bank_head_id
        $where
        ORDER BY e.entry_date DESC, e.id DESC
      '''),
      parameters: headId == null ? const {} : {'head_id': headId},
    );
    return r.map((row) => BankEntryModel.fromMap(row.toColumnMap())).toList();
  }

  Future<void> insertEntry(BankEntryModel e) => _conn.execute(
        Sql.named('''
          INSERT INTO bank_entry (bank_head_id, entry_date, type, amount, description)
          VALUES (@bank_head_id, @entry_date, @type, @amount, @description)
        '''),
        parameters: e.toMap()..remove('id'),
      );

  Future<void> updateEntry(BankEntryModel e) => _conn.execute(
        Sql.named('''
          UPDATE bank_entry SET
            bank_head_id = @bank_head_id, entry_date = @entry_date, type = @type,
            amount = @amount, description = @description
          WHERE id = @id
        '''),
        parameters: e.toMap(),
      );

  Future<void> deleteEntry(int id) => _conn.execute(
        Sql.named('DELETE FROM bank_entry WHERE id = @id'),
        parameters: {'id': id},
      );
}
