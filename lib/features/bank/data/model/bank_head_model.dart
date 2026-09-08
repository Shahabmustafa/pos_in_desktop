/// A bank account ("head") the business keeps money in.
class BankHeadModel {
  const BankHeadModel({
    this.id,
    required this.title,
    this.bankName = '',
    this.accountNumber = '',
    this.openingBalance = 0,
    this.isActive = true,
  });

  final int? id;

  /// Account title, e.g. "Meezan – Current".
  final String title;
  final String bankName;
  final String accountNumber;
  final double openingBalance;
  final bool isActive;

  factory BankHeadModel.fromMap(Map<String, dynamic> map) {
    return BankHeadModel(
      id: map['id'] as int?,
      title: (map['title'] as String?) ?? '',
      bankName: (map['bank_name'] as String?) ?? '',
      accountNumber: (map['account_number'] as String?) ?? '',
      openingBalance: _toDouble(map['opening_balance']),
      isActive: (map['is_active'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'bank_name': bankName,
        'account_number': accountNumber,
        'opening_balance': openingBalance,
        'is_active': isActive,
      };

  BankHeadModel copyWith({
    int? id,
    String? title,
    String? bankName,
    String? accountNumber,
    double? openingBalance,
    bool? isActive,
  }) {
    return BankHeadModel(
      id: id ?? this.id,
      title: title ?? this.title,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      openingBalance: openingBalance ?? this.openingBalance,
      isActive: isActive ?? this.isActive,
    );
  }

  static double _toDouble(Object? v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}
