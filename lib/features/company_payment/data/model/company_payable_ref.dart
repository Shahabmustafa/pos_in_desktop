/// A company (supplier) reference for the payment picker, carrying how much
/// the business currently owes them.
///
/// [payable] is `company.opening_balance` — kept live by Purchase Invoice
/// (the unpaid portion of each bill), Purchase Return and this feature's own
/// payments, the same way `customer.opening_balance` works.
class CompanyPayableRef {
  const CompanyPayableRef({
    required this.id,
    required this.name,
    required this.payable,
  });

  final int id;
  final String name;
  final double payable;

  factory CompanyPayableRef.fromMap(Map<String, dynamic> map) =>
      CompanyPayableRef(
        id: map['id'] as int,
        name: (map['name'] as String?) ?? '',
        payable: _toDouble(map['payable']),
      );

  @override
  bool operator ==(Object other) => other is CompanyPayableRef && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => name;

  static double _toDouble(Object? v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}
