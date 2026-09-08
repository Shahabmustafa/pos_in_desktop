/// Direction of a bank entry.
enum BankEntryType {
  deposit,
  withdraw;

  String get label => this == BankEntryType.deposit ? 'Deposit' : 'Withdraw';

  /// +1 for deposit, -1 for withdraw.
  int get sign => this == BankEntryType.deposit ? 1 : -1;

  static BankEntryType fromDb(String? v) =>
      v == 'withdraw' ? BankEntryType.withdraw : BankEntryType.deposit;

  String get db => name;
}

/// A single money movement against a [BankHeadModel].
class BankEntryModel {
  const BankEntryModel({
    this.id,
    required this.bankHeadId,
    required this.date,
    required this.type,
    required this.amount,
    this.description = '',
    this.bankHeadTitle = '',
  });

  final int? id;
  final int bankHeadId;
  final DateTime date;
  final BankEntryType type;
  final double amount;
  final String description;

  /// Joined from `bank_head.title` for display only.
  final String bankHeadTitle;

  /// Signed amount: +deposit / -withdraw.
  double get signedAmount => amount * type.sign;

  factory BankEntryModel.fromMap(Map<String, dynamic> map) {
    return BankEntryModel(
      id: map['id'] as int?,
      bankHeadId: map['bank_head_id'] as int,
      date: _toDate(map['entry_date']),
      type: BankEntryType.fromDb(map['type'] as String?),
      amount: _toDouble(map['amount']),
      description: (map['description'] as String?) ?? '',
      bankHeadTitle: (map['bank_head_title'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'bank_head_id': bankHeadId,
        'entry_date': date,
        'type': type.db,
        'amount': amount,
        'description': description,
      };

  BankEntryModel copyWith({
    int? id,
    int? bankHeadId,
    DateTime? date,
    BankEntryType? type,
    double? amount,
    String? description,
    String? bankHeadTitle,
  }) {
    return BankEntryModel(
      id: id ?? this.id,
      bankHeadId: bankHeadId ?? this.bankHeadId,
      date: date ?? this.date,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      bankHeadTitle: bankHeadTitle ?? this.bankHeadTitle,
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
