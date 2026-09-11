/// A payment collected from a customer against their outstanding balance —
/// independent of any particular sale invoice. Reduces `customer.opening_balance`
/// the same way a sale invoice's unpaid portion increases it.
class CustomerPaymentModel {
  const CustomerPaymentModel({
    this.id,
    this.paymentNo = '',
    required this.date,
    required this.customerId,
    this.customerName = '',
    this.amount = 0,
    this.bankHeadId,
    this.reference = '',
    this.narration = '',
  });

  final int? id;
  final String paymentNo;
  final DateTime date;
  final int customerId;
  final String customerName;
  final double amount;

  /// Non-null when the money was deposited into this bank account instead of
  /// the cash drawer.
  final int? bankHeadId;

  final String reference;
  final String narration;

  factory CustomerPaymentModel.fromMap(Map<String, dynamic> map) {
    return CustomerPaymentModel(
      id: map['id'] as int?,
      paymentNo: (map['payment_no'] as String?) ?? '',
      date: _toDate(map['payment_date']),
      customerId: map['customer_id'] as int,
      customerName: (map['customer_name'] as String?) ?? '',
      amount: _toDouble(map['amount']),
      bankHeadId: map['bank_head_id'] as int?,
      reference: (map['reference'] as String?) ?? '',
      narration: (map['narration'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'payment_no': paymentNo,
        'payment_date': date,
        'customer_id': customerId,
        'customer_name': customerName,
        'amount': amount,
        'bank_head_id': bankHeadId,
        'reference': reference,
        'narration': narration,
      };

  CustomerPaymentModel copyWith({
    int? id,
    String? paymentNo,
    DateTime? date,
    int? customerId,
    String? customerName,
    double? amount,
    int? bankHeadId,
    bool clearBankHeadId = false,
    String? reference,
    String? narration,
  }) {
    return CustomerPaymentModel(
      id: id ?? this.id,
      paymentNo: paymentNo ?? this.paymentNo,
      date: date ?? this.date,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      amount: amount ?? this.amount,
      bankHeadId: clearBankHeadId ? null : (bankHeadId ?? this.bankHeadId),
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
