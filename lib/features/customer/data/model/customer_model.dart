/// Data model for the Customer feature.
class CustomerModel {
  const CustomerModel({
    this.id,
    required this.name,
    this.email = '',
    this.address = '',
    this.phone = '',
    this.openingBalance = 0,
    this.isActive = true,
  });

  /// `null` for a not-yet-saved customer.
  final int? id;
  final String name;
  final String email;
  final String address;
  final String phone;
  final double openingBalance;
  final bool isActive;

  factory CustomerModel.fromMap(Map<String, dynamic> map) {
    return CustomerModel(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? '',
      email: (map['email'] as String?) ?? '',
      address: (map['address'] as String?) ?? '',
      phone: (map['phone'] as String?) ?? '',
      openingBalance: _toDouble(map['opening_balance']),
      isActive: (map['is_active'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'email': email,
        'address': address,
        'phone': phone,
        'opening_balance': openingBalance,
        'is_active': isActive,
      };

  CustomerModel copyWith({
    int? id,
    String? name,
    String? email,
    String? address,
    String? phone,
    double? openingBalance,
    bool? isActive,
  }) {
    return CustomerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      address: address ?? this.address,
      phone: phone ?? this.phone,
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
