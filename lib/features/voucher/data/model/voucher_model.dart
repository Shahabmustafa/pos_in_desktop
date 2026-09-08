/// Kind of voucher.
enum VoucherType {
  payment,
  receipt,
  journal;

  String get label => switch (this) {
        VoucherType.payment => 'Payment',
        VoucherType.receipt => 'Receipt',
        VoucherType.journal => 'Journal',
      };

  /// +1 when money comes in (receipt), -1 when it goes out (payment), 0 journal.
  int get cashSign => switch (this) {
        VoucherType.receipt => 1,
        VoucherType.payment => -1,
        VoucherType.journal => 0,
      };

  String get db => name;

  static VoucherType fromDb(String? v) => switch (v) {
        'receipt' => VoucherType.receipt,
        'journal' => VoucherType.journal,
        _ => VoucherType.payment,
      };
}

/// How a voucher was settled.
enum VoucherMode {
  cash,
  bank;

  String get label => this == VoucherMode.cash ? 'Cash' : 'Bank';
  String get db => name;

  static VoucherMode fromDb(String? v) =>
      v == 'bank' ? VoucherMode.bank : VoucherMode.cash;
}

/// A payment / receipt / journal voucher.
class VoucherModel {
  const VoucherModel({
    this.id,
    this.voucherNo = '',
    required this.date,
    this.type = VoucherType.payment,
    this.party = '',
    this.amount = 0,
    this.mode = VoucherMode.cash,
    this.reference = '',
    this.narration = '',
  });

  final int? id;
  final String voucherNo;
  final DateTime date;
  final VoucherType type;

  /// Who the money was paid to / received from.
  final String party;
  final double amount;
  final VoucherMode mode;
  final String reference;
  final String narration;

  double get signedAmount => amount * type.cashSign;

  factory VoucherModel.fromMap(Map<String, dynamic> map) {
    return VoucherModel(
      id: map['id'] as int?,
      voucherNo: (map['voucher_no'] as String?) ?? '',
      date: _toDate(map['voucher_date']),
      type: VoucherType.fromDb(map['type'] as String?),
      party: (map['party'] as String?) ?? '',
      amount: _toDouble(map['amount']),
      mode: VoucherMode.fromDb(map['payment_mode'] as String?),
      reference: (map['reference'] as String?) ?? '',
      narration: (map['narration'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'voucher_no': voucherNo,
        'voucher_date': date,
        'type': type.db,
        'party': party,
        'amount': amount,
        'payment_mode': mode.db,
        'reference': reference,
        'narration': narration,
      };

  VoucherModel copyWith({
    int? id,
    String? voucherNo,
    DateTime? date,
    VoucherType? type,
    String? party,
    double? amount,
    VoucherMode? mode,
    String? reference,
    String? narration,
  }) {
    return VoucherModel(
      id: id ?? this.id,
      voucherNo: voucherNo ?? this.voucherNo,
      date: date ?? this.date,
      type: type ?? this.type,
      party: party ?? this.party,
      amount: amount ?? this.amount,
      mode: mode ?? this.mode,
      reference: reference ?? this.reference,
      narration: narration ?? this.narration,
    );
  }

  static double _toDouble(Object? v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static DateTime _toDate(Object? v) {
    if (v is DateTime) return v;
    return DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
  }
}
