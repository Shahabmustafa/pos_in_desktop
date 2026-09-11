/// A payment made to a company (supplier) against what the business owes
/// them — independent of any particular purchase invoice.
///
/// Unlike the customer side, `company.opening_balance` is a true, never-
/// mutated opening figure (purchase invoices/returns don't touch it either),
/// so a payment here does not adjust it. What the business currently owes a
/// company is instead worked out live — see `CompanyPayableRef`.
class CompanyPaymentModel {
  const CompanyPaymentModel({
    this.id,
    this.paymentNo = '',
    required this.date,
    required this.companyId,
    this.companyName = '',
    this.amount = 0,
    this.bankHeadId,
    this.reference = '',
    this.narration = '',
  });

  final int? id;
  final String paymentNo;
  final DateTime date;
  final int companyId;
  final String companyName;
  final double amount;

  /// Non-null when the money was paid out of this bank account instead of
  /// the cash drawer.
  final int? bankHeadId;

  final String reference;
  final String narration;

  factory CompanyPaymentModel.fromMap(Map<String, dynamic> map) {
    return CompanyPaymentModel(
      id: map['id'] as int?,
      paymentNo: (map['payment_no'] as String?) ?? '',
      date: _toDate(map['payment_date']),
      companyId: map['company_id'] as int,
      companyName: (map['company_name'] as String?) ?? '',
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
        'company_id': companyId,
        'company_name': companyName,
        'amount': amount,
        'bank_head_id': bankHeadId,
        'reference': reference,
        'narration': narration,
      };

  CompanyPaymentModel copyWith({
    int? id,
    String? paymentNo,
    DateTime? date,
    int? companyId,
    String? companyName,
    double? amount,
    int? bankHeadId,
    bool clearBankHeadId = false,
    String? reference,
    String? narration,
  }) {
    return CompanyPaymentModel(
      id: id ?? this.id,
      paymentNo: paymentNo ?? this.paymentNo,
      date: date ?? this.date,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
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
