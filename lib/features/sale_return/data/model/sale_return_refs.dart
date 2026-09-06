// Lightweight `{id, name}` style references used by the sale return form's
// pickers.

/// A customer the return is credited to. Fed from the `customer` table.
class CustomerRef {
  const CustomerRef({
    required this.id,
    required this.name,
    this.openingBalance = 0,
  });

  final int id;
  final String name;

  /// The customer's running balance in `customer.opening_balance`.
  final double openingBalance;

  factory CustomerRef.fromMap(Map<String, dynamic> map) => CustomerRef(
        id: map['id'] as int,
        name: (map['name'] as String?) ?? '',
        openingBalance: _refToDouble(map['opening_balance']),
      );

  @override
  bool operator ==(Object other) => other is CustomerRef && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => name;
}

/// A product that can be added as a return line. Fed from `stock_item`.
class ProductRef {
  const ProductRef({
    required this.id,
    required this.name,
    this.barcode = '',
    this.unit = 'pcs',
    this.salePrice = 0,
    this.tax = 0,
    this.quantity = 0,
  });

  final int id;
  final String name;
  final String barcode;
  final String unit;
  final double salePrice;
  final double tax;

  /// On-hand quantity in `stock_item`.
  final double quantity;

  factory ProductRef.fromMap(Map<String, dynamic> map) => ProductRef(
        id: map['id'] as int,
        name: (map['name'] as String?) ?? '',
        barcode: (map['barcode'] as String?) ?? '',
        unit: (map['unit'] as String?) ?? 'pcs',
        salePrice: _toDouble(map['sale_price']),
        tax: _toDouble(map['tax']),
        quantity: _toDouble(map['quantity']),
      );

  @override
  bool operator ==(Object other) => other is ProductRef && other.id == id;

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

double _refToDouble(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}
