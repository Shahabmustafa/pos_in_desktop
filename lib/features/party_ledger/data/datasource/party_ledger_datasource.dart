import 'package:postgres/postgres.dart';

import '../../../../config/database/database_connection.dart';
import '../model/party_ledger_model.dart';

/// Reads PostgreSQL for the Party Ledger feature. Every query is read-only.
/// A source table that does not exist yet (42P01) or is missing a column
/// (42703) just drops out of the statement instead of failing it — same
/// contract as `ReportsDataSource`.
class PartyLedgerDataSource {
  const PartyLedgerDataSource();

  Connection get _conn => Database.instance.connection;

  // ── Pickers ────────────────────────────────────────────────────────
  Future<List<PartyRef>> customers() => _parties('customer');
  Future<List<PartyRef>> companies() => _parties('company');

  Future<List<PartyRef>> _parties(String table) async {
    final rows = await _guard(
      () => _conn.execute(
        'SELECT id, name, opening_balance FROM $table '
        'WHERE is_active = TRUE ORDER BY name',
      ),
      null,
    );
    if (rows == null) return const [];
    return rows.map((r) => PartyRef.fromMap(r.toColumnMap())).toList();
  }

  // ── Ledgers ────────────────────────────────────────────────────────
  Future<PartyLedger> customerLedger(
      PartyRef party, DateTime from, DateTime to) async {
    final moves = <LedgerEntry>[];

    // 1. Sale invoice — the full bill is a debit; cash taken at billing is a
    //    same-day credit.
    await _collect(moves, '''
      SELECT invoice_date AS d, id AS ord, invoice_no AS doc, notes AS detail,
             grand_total AS amt, amount_received AS paid
      FROM sale_invoice WHERE customer_id = @pid
    ''', {'pid': party.id}, (m) {
      final out = <LedgerEntry>[
        LedgerEntry(
          date: _dt(m['d']),
          type: 'Sale',
          docNo: _doc(m['doc']),
          detail: _text(m['detail']),
          debit: _d(m['amt']),
          credit: 0,
          sortKey: (m['ord'] as int) * 10,
        ),
      ];
      final paid = _d(m['paid']);
      if (paid != 0) {
        out.add(LedgerEntry(
          date: _dt(m['d']),
          type: 'Receipt',
          docNo: _doc(m['doc']),
          detail: 'Cash at billing',
          debit: 0,
          credit: paid,
          sortKey: (m['ord'] as int) * 10 + 1,
        ));
      }
      return out;
    });

    // 2. Sale return — goods came back, a credit; cash refunded is a debit.
    await _collect(moves, '''
      SELECT return_date AS d, id AS ord, invoice_no AS doc, notes AS detail,
             grand_total AS amt, amount_paid AS refund
      FROM sale_return WHERE customer_id = @pid
    ''', {'pid': party.id}, (m) {
      final out = <LedgerEntry>[
        LedgerEntry(
          date: _dt(m['d']),
          type: 'Sale Return',
          docNo: _doc(m['doc']),
          detail: _text(m['detail']),
          debit: 0,
          credit: _d(m['amt']),
          sortKey: (m['ord'] as int) * 10,
        ),
      ];
      final refund = _d(m['refund']);
      if (refund != 0) {
        out.add(LedgerEntry(
          date: _dt(m['d']),
          type: 'Refund',
          docNo: _doc(m['doc']),
          detail: 'Cash refunded',
          debit: refund,
          credit: 0,
          sortKey: (m['ord'] as int) * 10 + 1,
        ));
      }
      return out;
    });

    // 3. Customer payment — money collected outside a sale invoice, a credit.
    await _collect(moves, '''
      SELECT payment_date AS d, id AS ord, payment_no AS doc, narration AS detail,
             amount AS amt
      FROM customer_payment WHERE customer_id = @pid
    ''', {'pid': party.id}, (m) => [
          LedgerEntry(
            date: _dt(m['d']),
            type: 'Receipt',
            docNo: _doc(m['doc']),
            detail: _text(m['detail']),
            debit: 0,
            credit: _d(m['amt']),
            sortKey: (m['ord'] as int) * 10,
          ),
        ]);

    // Customer: stored balance is the live receivable → treat it as the
    // closing figure and work the opening back from it.
    return PartyLedger.assemble(
      kind: LedgerKind.customer,
      partyName: party.name,
      moves: moves,
      anchor: party.storedBalance,
      anchorIsClosing: true,
      from: from,
      to: to,
    );
  }

  Future<PartyLedger> companyLedger(
      PartyRef party, DateTime from, DateTime to) async {
    final moves = <LedgerEntry>[];

    // Purchase invoice — you owe the supplier more, a debit; cash paid at
    // purchase time is a same-day credit.
    await _collect(moves, '''
      SELECT invoice_date AS d, id AS ord, invoice_no AS doc, notes AS detail,
             grand_total AS amt, amount_paid AS paid
      FROM purchase_invoice WHERE company_id = @pid
    ''', {'pid': party.id}, (m) {
      final out = <LedgerEntry>[
        LedgerEntry(
          date: _dt(m['d']),
          type: 'Purchase',
          docNo: _doc(m['doc']),
          detail: _text(m['detail']),
          debit: _d(m['amt']),
          credit: 0,
          sortKey: (m['ord'] as int) * 10,
        ),
      ];
      final paid = _d(m['paid']);
      if (paid != 0) {
        out.add(LedgerEntry(
          date: _dt(m['d']),
          type: 'Payment',
          docNo: _doc(m['doc']),
          detail: 'Cash at purchase',
          debit: 0,
          credit: paid,
          sortKey: (m['ord'] as int) * 10 + 1,
        ));
      }
      return out;
    });

    // Purchase return — goods sent back, you owe less, a credit.
    await _collect(moves, '''
      SELECT return_date AS d, id AS ord, invoice_no AS doc, remarks AS detail,
             grand_total AS amt
      FROM purchase_return WHERE company_id = @pid
    ''', {'pid': party.id}, (m) => [
          LedgerEntry(
            date: _dt(m['d']),
            type: 'Purchase Return',
            docNo: _doc(m['doc']),
            detail: _text(m['detail']),
            debit: 0,
            credit: _d(m['amt']),
            sortKey: (m['ord'] as int) * 10,
          ),
        ]);

    // Company payment — money paid outside a purchase invoice, a debit-reducer.
    await _collect(moves, '''
      SELECT payment_date AS d, id AS ord, payment_no AS doc, narration AS detail,
             amount AS amt
      FROM company_payment WHERE company_id = @pid
    ''', {'pid': party.id}, (m) => [
          LedgerEntry(
            date: _dt(m['d']),
            type: 'Payment',
            docNo: _doc(m['doc']),
            detail: _text(m['detail']),
            debit: 0,
            credit: _d(m['amt']),
            sortKey: (m['ord'] as int) * 10,
          ),
        ]);

    // Company: stored balance is the live payable → treat it as the closing
    // figure and work the opening back from it (same as the customer side).
    return PartyLedger.assemble(
      kind: LedgerKind.company,
      partyName: party.name,
      moves: moves,
      anchor: party.storedBalance,
      anchorIsClosing: true,
      from: from,
      to: to,
    );
  }

  // ── helpers ────────────────────────────────────────────────────────

  /// Runs [sql], mapping each row to zero or more [LedgerEntry] via [rowToEntries],
  /// and appends them to [into]. A missing table / column is swallowed.
  Future<void> _collect(
    List<LedgerEntry> into,
    String sql,
    Map<String, Object?> params,
    List<LedgerEntry> Function(Map<String, dynamic> row) rowToEntries,
  ) async {
    final rows = await _guard(
      () => _conn.execute(Sql.named(sql), parameters: params),
      null,
    );
    if (rows == null) return;
    for (final row in rows) {
      into.addAll(rowToEntries(row.toColumnMap()));
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

  static DateTime _dt(Object? v) {
    if (v is DateTime) return v;
    return DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
  }

  static String _doc(Object? v) =>
      (v as String?)?.trim().isNotEmpty == true ? (v as String).trim() : '—';

  static String _text(Object? v) => (v as String?)?.trim() ?? '';

  static double _d(Object? v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}
