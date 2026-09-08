/// How an expense was paid.
enum ExpensePaymentMode {
  cash,
  bank;

  String get label => this == ExpensePaymentMode.cash ? 'Cash' : 'Bank';

  static ExpensePaymentMode fromDb(String? v) =>
      v == 'bank' ? ExpensePaymentMode.bank : ExpensePaymentMode.cash;

  String get db => name;
}

/// A single spend recorded against an [ExpenseHeadModel].
class ExpenseEntryModel {
  const ExpenseEntryModel({
    this.id,
    required this.expenseHeadId,
    required this.date,
    required this.amount,
    this.paymentMode = ExpensePaymentMode.cash,
    this.description = '',
    this.expenseHeadName = '',
  });

  final int? id;
  final int expenseHeadId;
  final DateTime date;
  final double amount;
  final ExpensePaymentMode paymentMode;
  final String description;

  /// Joined from `expense_head.name` for display only.
  final String expenseHeadName;

  factory ExpenseEntryModel.fromMap(Map<String, dynamic> map) {
    return ExpenseEntryModel(
      id: map['id'] as int?,
      expenseHeadId: map['expense_head_id'] as int,
      date: _toDate(map['entry_date']),
      amount: _toDouble(map['amount']),
      paymentMode: ExpensePaymentMode.fromDb(map['payment_mode'] as String?),
      description: (map['description'] as String?) ?? '',
      expenseHeadName: (map['expense_head_name'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'expense_head_id': expenseHeadId,
        'entry_date': date,
        'amount': amount,
        'payment_mode': paymentMode.db,
        'description': description,
      };

  ExpenseEntryModel copyWith({
    int? id,
    int? expenseHeadId,
    DateTime? date,
    double? amount,
    ExpensePaymentMode? paymentMode,
    String? description,
    String? expenseHeadName,
  }) {
    return ExpenseEntryModel(
      id: id ?? this.id,
      expenseHeadId: expenseHeadId ?? this.expenseHeadId,
      date: date ?? this.date,
      amount: amount ?? this.amount,
      paymentMode: paymentMode ?? this.paymentMode,
      description: description ?? this.description,
      expenseHeadName: expenseHeadName ?? this.expenseHeadName,
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
