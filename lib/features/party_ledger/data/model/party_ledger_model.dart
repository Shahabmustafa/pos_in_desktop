/// Models for the Party Ledger feature — an account statement for one
/// customer or one company: opening balance, the documents that moved it in a
/// date range, a running balance, and a closing figure.
///
/// Nothing here is stored. A ledger is built on read from `sale_invoice` /
/// `sale_return` (customer) or `purchase_invoice` / `purchase_return`
/// (company), the same way the Reports feature builds its tables.
library;

/// Which kind of party a ledger is for.
enum LedgerKind {
  customer('Customer', 'People you sell to'),
  company('Company', 'Suppliers you buy from');

  const LedgerKind(this.label, this.blurb);

  final String label;
  final String blurb;
}

/// A `{id, name}` reference plus the party's stored balance, used to fill the
/// picker and to anchor the running balance.
///
/// * For a **customer** [storedBalance] is `customer.opening_balance`, which the
///   sale-invoice / sale-return datasources keep as the *live* receivable — so
///   here it is treated as the ledger's **closing** figure and the opening is
///   worked back from it (the same trick the Stock report uses).
/// * For a **company** [storedBalance] is `company.opening_balance`, a true
///   opening that nothing mutates, so it anchors the ledger from the front.
class PartyRef {
  const PartyRef({
    required this.id,
    required this.name,
    required this.storedBalance,
  });

  final int id;
  final String name;
  final double storedBalance;

  factory PartyRef.fromMap(Map<String, dynamic> map) => PartyRef(
        id: map['id'] as int,
        name: (map['name'] as String?)?.trim().isNotEmpty == true
            ? (map['name'] as String).trim()
            : '(unnamed)',
        storedBalance: _d(map['opening_balance']),
      );

  @override
  bool operator ==(Object other) => other is PartyRef && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => name;
}

/// One line in the statement.
class LedgerEntry {
  LedgerEntry({
    required this.date,
    required this.type,
    required this.docNo,
    required this.detail,
    required this.debit,
    required this.credit,
    required this.sortKey,
  });

  final DateTime date;

  /// 'Sale', 'Receipt', 'Sale Return', 'Refund', 'Purchase', 'Purchase Return'.
  final String type;
  final String docNo;
  final String detail;

  /// Raises the balance (customer owes more / you owe the supplier more).
  final double debit;

  /// Lowers the balance.
  final double credit;

  /// Source row id — a stable tie-break for rows that share a date.
  final int sortKey;

  /// Filled once the entries are ordered.
  double runningBalance = 0;
}

/// A finished statement for one party over one date range.
class PartyLedger {
  const PartyLedger({
    required this.kind,
    required this.partyName,
    required this.opening,
    required this.entries,
  });

  final LedgerKind kind;
  final String partyName;

  /// Balance as of the first day of the range.
  final double opening;

  /// Movements inside the range, oldest first, with [LedgerEntry.runningBalance]
  /// already computed.
  final List<LedgerEntry> entries;

  double get totalDebit => entries.fold(0, (a, e) => a + e.debit);
  double get totalCredit => entries.fold(0, (a, e) => a + e.credit);
  double get closing => opening + totalDebit - totalCredit;

  static const PartyLedger none = PartyLedger(
    kind: LedgerKind.customer,
    partyName: '',
    opening: 0,
    entries: [],
  );

  /// Orders [moves], folds everything before [from] into the opening balance,
  /// keeps the rows within `[from, to]`, and walks the running balance forward.
  ///
  /// [anchor] is the number we trust: for a customer it is the stored
  /// `opening_balance`, which is really the live **closing** balance, so
  /// [anchorIsClosing] is `true` and the opening is worked back from it. For a
  /// company it is a genuine opening and [anchorIsClosing] is `false`.
  static PartyLedger assemble({
    required LedgerKind kind,
    required String partyName,
    required List<LedgerEntry> moves,
    required double anchor,
    required bool anchorIsClosing,
    required DateTime from,
    required DateTime to,
  }) {
    var seq = 0;
    final indexed = [for (final m in moves) (seq++, m)];
    indexed.sort((a, b) {
      final d = a.$2.date.compareTo(b.$2.date);
      if (d != 0) return d;
      final k = a.$2.sortKey.compareTo(b.$2.sortKey);
      return k != 0 ? k : a.$1.compareTo(b.$1);
    });
    final ordered = [for (final e in indexed) e.$2];

    double net(Iterable<LedgerEntry> xs) =>
        xs.fold(0.0, (a, e) => a + e.debit - e.credit);

    final fromDay = _dateOnly(from);
    final toDay = _dateOnly(to);
    bool before(LedgerEntry e) => _dateOnly(e.date).isBefore(fromDay);
    bool within(LedgerEntry e) {
      final day = _dateOnly(e.date);
      return !day.isBefore(fromDay) && !day.isAfter(toDay);
    }

    final trueOpening = anchorIsClosing ? anchor - net(ordered) : anchor;
    final opening = trueOpening + net(ordered.where(before));

    final entries = ordered.where(within).toList();
    var bal = opening;
    for (final e in entries) {
      bal += e.debit - e.credit;
      e.runningBalance = bal;
    }

    return PartyLedger(
      kind: kind,
      partyName: partyName,
      opening: opening,
      entries: entries,
    );
  }
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

double _d(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}
