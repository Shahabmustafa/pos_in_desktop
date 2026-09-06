/// One product line on a purchase-return invoice.
class PurchaseReturnItemModel {
  const PurchaseReturnItemModel({
    this.id,
    this.productId,
    required this.productName,
    this.barcode = '',
    this.quantity = 1,
    this.unitPrice = 0,
    this.salePrice = 0,
    this.discount = 0,
    this.tax = 0,
  });

  final int? id;

  /// Foreign key into `stock_item`. May be `null` if the product was removed.
  final int? productId;
  final String productName;
  final String barcode;
  final double quantity;

  /// Price per unit being returned (defaults to the product's purchase price).
  final double unitPrice;

  /// Selling price captured on this line (record only — does not change the
  /// product's stock sale price).
  final double salePrice;

  /// Discount percentage on the line.
  final double discount;

  /// Tax percentage on the line.
  final double tax;

  /// price * qty, before discount / tax.
  double get gross => unitPrice * quantity;

  double get discountAmount => gross * discount / 100;

  double get taxAmount => (gross - discountAmount) * tax / 100;

  /// What the supplier owes back for this line.
  double get lineTotal => gross - discountAmount + taxAmount;

  factory PurchaseReturnItemModel.fromMap(Map<String, dynamic> map) {
    return PurchaseReturnItemModel(
      id: map['id'] as int?,
      productId: map['product_id'] as int?,
      productName: (map['product_name'] as String?) ?? '',
      barcode: (map['barcode'] as String?) ?? '',
      quantity: _toDouble(map['quantity']),
      unitPrice: _toDouble(map['unit_price']),
      salePrice: _toDouble(map['sale_price']),
      discount: _toDouble(map['discount']),
      tax: _toDouble(map['tax']),
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'product_id': productId,
        'product_name': productName,
        'barcode': barcode,
        'quantity': quantity,
        'unit_price': unitPrice,
        'sale_price': salePrice,
        'discount': discount,
        'tax': tax,
        'line_total': lineTotal,
      };

  PurchaseReturnItemModel copyWith({
    int? id,
    Object? productId = _sentinel,
    String? productName,
    String? barcode,
    double? quantity,
    double? unitPrice,
    double? salePrice,
    double? discount,
    double? tax,
  }) {
    return PurchaseReturnItemModel(
      id: id ?? this.id,
      productId:
          identical(productId, _sentinel) ? this.productId : productId as int?,
      productName: productName ?? this.productName,
      barcode: barcode ?? this.barcode,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      salePrice: salePrice ?? this.salePrice,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
    );
  }

  static const Object _sentinel = Object();

  static double _toDouble(Object? v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}
