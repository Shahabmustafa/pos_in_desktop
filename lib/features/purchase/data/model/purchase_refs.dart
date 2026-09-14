// Lightweight `{id, name}` style references used by the purchase invoice
// form's pickers.

double _toDouble(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

/// A company (supplier) the invoice can be booked against. Fed from the
/// `company` master table.
class CompanyRef {
  const CompanyRef({
    required this.id,
    required this.name,
    this.openingBalance = 0,
  });

  final int id;
  final String name;

  /// The company's running balance in `company.opening_balance` — kept live
  /// by purchase invoices (unpaid portion), purchase returns and Pay Company
  /// payments, the same way `customer.opening_balance` works.
  final double openingBalance;

  factory CompanyRef.fromMap(Map<String, dynamic> map) => CompanyRef(
        id: map['id'] as int,
        name: (map['name'] as String?) ?? '',
        openingBalance: _toDouble(map['opening_balance']),
      );

  /// Equality by [id] so a value coming back from a dropdown matches the
  /// instance in the items list.
  @override
  bool operator ==(Object other) => other is CompanyRef && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => name;
}

/// A product that can be added as an invoice line. Fed from the `stock_item`
/// table; carries the last purchase price so the form can pre-fill it.
class ProductRef {
  const ProductRef({
    required this.id,
    required this.name,
    this.barcode = '',
    this.unit = 'pcs',
    this.purchasePrice = 0,
    this.salePrice = 0,
    this.quantity = 0,
  });

  final int id;
  final String name;
  final String barcode;
  final String unit;
  final double purchasePrice;
  final double salePrice;

  /// On-hand quantity in `stock_item`.
  final double quantity;

  factory ProductRef.fromMap(Map<String, dynamic> map) => ProductRef(
        id: map['id'] as int,
        name: (map['name'] as String?) ?? '',
        barcode: (map['barcode'] as String?) ?? '',
        unit: (map['unit'] as String?) ?? 'pcs',
        purchasePrice: _toDouble(map['purchase_price']),
        salePrice: _toDouble(map['sale_price']),
        quantity: _toDouble(map['quantity']),
      );

  @override
  bool operator ==(Object other) => other is ProductRef && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => name;
}
