/// Models for the Cash Register feature — a cash book for the money in the
/// drawer: an opening float, every cash movement (auto from cash sales /
/// refunds / cash expenses / cash vouchers, plus manual entries), a running
/// balance, and the closing "cash in hand".
///
/// Only [CashAccount] and [CashEntry] are stored. The cash book itself is
/// computed on read, the same way the Party Ledger and Reports are.
library;

/// The single cash drawer. Exactly one row exists (auto-created).
class CashAccount {
  CashAccount({
    this.id,
    this.title = 'Cash in Hand',
    this.openingBalance = 0,
    DateTime? openingDate,
  }) : openingDate = openingDate ?? DateTime(2000, 1, 1);

  final int? id;
  final String title;

  /// Cash on hand before the system started tracking, as of [openingDate].
  final double openingBalance;
  final DateTime openingDate;

  factory CashAccount.fromMap(Map<String, dynamic> map) => CashAccount(
        id: map['id'] as int?,
        title: (map['title'] as String?)?.trim().isNotEmpty == true
            ? (map['title'] as String).trim()
            : 'Cash in Hand',
        openingBalance: _d(map['opening_balance']),
        openingDate: _dt(map['opening_date']),
      );

  CashAccount copyWith({String? title, double? openingBalance, DateTime? openingDate}) =>
      CashAccount(
        id: id,
        title: title ?? this.title,
        openingBalance: openingBalance ?? this.openingBalance,
        openingDate: openingDate ?? this.openingDate,
      );
}

/// Direction of a cash movement.
enum CashDirection {
  cashIn('in', 'Cash In'),
  cashOut('out', 'Cash Out');

  const CashDirection(this.db, this.label);

  final String db;
  final String label;

  int get sign => this == CashDirection.cashIn ? 1 : -1;

  static CashDirection fromDb(String? v) =>
      v == 'out' ? CashDirection.cashOut : CashDirection.cashIn;
}

/// A hand-entered cash movement — an opening float top-up, cash taken to the
/// bank, an owner drawing, a count adjustment, petty cash, etc.
class CashEntry {
  const CashEntry({
    this.id,
    required this.date,
    this.direction = CashDirection.cashOut,
    this.amount = 0,
    this.category = '',
    this.description = '',
  });

  final int? id;
  final DateTime date;
  final CashDirection direction;
  final double amount;

  /// A short bucket: 'Bank deposit', 'Bank withdrawal', 'Owner drawing',
  /// 'Opening float', 'Adjustment', or free text.
  final String category;
  final String description;

  double get signedAmount => amount * direction.sign;

  factory CashEntry.fromMap(Map<String, dynamic> map) => CashEntry(
        id: map['id'] as int?,
        date: _dt(map['entry_date']),
        direction: CashDirection.fromDb(map['type'] as String?),
        amount: _d(map['amount']),
        category: (map['category'] as String?)?.trim() ?? '',
        description: (map['description'] as String?)?.trim() ?? '',
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'entry_date': date,
        'type': direction.db,
        'amount': amount,
        'category': category,
        'description': description,
      };

  CashEntry copyWith({
    int? id,
    DateTime? date,
    CashDirection? direction,
    double? amount,
    String? category,
    String? description,
  }) =>
      CashEntry(
        id: id ?? this.id,
        date: date ?? this.date,
        direction: direction ?? this.direction,
        amount: amount ?? this.amount,
        category: category ?? this.category,
        description: description ?? this.description,
      );

  static const List<String> categories = [
    'Bank deposit',
    'Bank withdrawal',
    'Owner drawing',
    'Opening float',
    'Adjustment',
  ];
}

/// One line in the cash book.
class CashMovement {
  CashMovement({
    required this.date,
    required this.type,
    required this.category,
    required this.detail,
    required this.inAmount,
    required this.outAmount,
    required this.sortKey,
    this.manualId,
  });

  final DateTime date;

  /// 'Sale', 'Refund', 'Expense', 'Receipt', 'Payment', 'Cash In', 'Cash Out'.
  final String type;
  final String category;
  final String detail;
  final double inAmount;
  final double outAmount;
  final int sortKey;

  /// `cash_entry.id` when this row is a hand-entered movement (editable).
  final int? manualId;

  bool get isManual => manualId != null;

  double runningBalance = 0;
}

/// A finished cash book for a date range.
class CashBook {
  const CashBook({
    required this.title,
    required this.opening,
    required this.entries,
    required this.cashInHand,
  });

  final String title;

  /// Balance as of the first day of the range.
  final double opening;

  /// Movements inside the range, oldest first, with [CashMovement.runningBalance].
  final List<CashMovement> entries;

  /// Live cash in the drawer right now: opening float + every cash movement up
  /// to today, independent of the selected range.
  final double cashInHand;

  double get totalIn => entries.fold(0, (a, e) => a + e.inAmount);
  double get totalOut => entries.fold(0, (a, e) => a + e.outAmount);
  double get closing => opening + totalIn - totalOut;

  static const CashBook empty =
      CashBook(title: 'Cash in Hand', opening: 0, entries: [], cashInHand: 0);

  /// Builds the book: order [moves], fold everything before [from] into the
  /// opening, keep the rows within `[from, to]`, walk the running balance, and
  /// separately total every movement up to [asOf] for [cashInHand].
  static CashBook build({
    required String title,
    required double openingFloat,
    required List<CashMovement> moves,
    required DateTime from,
    required DateTime to,
    required DateTime asOf,
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

    double net(Iterable<CashMovement> xs) =>
        xs.fold(0.0, (a, e) => a + e.inAmount - e.outAmount);

    final fromDay = _dateOnly(from);
    final toDay = _dateOnly(to);
    final asOfDay = _dateOnly(asOf);

    final opening = openingFloat +
        net(ordered.where((e) => _dateOnly(e.date).isBefore(fromDay)));

    final entries = ordered.where((e) {
      final day = _dateOnly(e.date);
      return !day.isBefore(fromDay) && !day.isAfter(toDay);
    }).toList();

    var bal = opening;
    for (final e in entries) {
      bal += e.inAmount - e.outAmount;
      e.runningBalance = bal;
    }

    final cashInHand = openingFloat +
        net(ordered.where((e) => !_dateOnly(e.date).isAfter(asOfDay)));

    return CashBook(
      title: title,
      opening: opening,
      entries: entries,
      cashInHand: cashInHand,
    );
  }
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime _dt(Object? v) {
  if (v is DateTime) return v;
  return DateTime.tryParse(v?.toString() ?? '') ?? DateTime(2000, 1, 1);
}

double _d(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}
