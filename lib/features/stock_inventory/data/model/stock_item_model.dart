/// A product in the inventory catalogue.
class StockItemModel {
  const StockItemModel({
    this.id,
    this.barcode = '',
    required this.name,
    this.sku = '',
    this.salePrice = 0,
    this.purchasePrice = 0,
    this.quantity = 0,
    this.discount = 0,
    this.tax = 0,
    this.expiryDate,
    this.unit = 'pcs',
    this.companyId,
    this.companyName = '',
    this.inventoryTypeId,
    this.inventoryType = '',
    this.categoryId,
    this.category = '',
    this.isActive = true,
  });

  final int? id;
  final String barcode;

  /// Product name.
  final String name;

  /// Stock keeping unit / item code.
  final String sku;
  final double salePrice;
  final double purchasePrice;

  /// Quantity on hand. Increased by purchase invoices, decreased by purchase
  /// returns; can also be set directly from the product form.
  final double quantity;

  /// Discount percentage.
  final double discount;

  /// Tax percentage.
  final double tax;
  final DateTime? expiryDate;

  /// pcs / kg / ltr / box …
  final String unit;

  /// Foreign key into `company`.
  final int? companyId;

  /// Company name — resolved from `company` for display, also stored as a
  /// snapshot on the row.
  final String companyName;

  /// Foreign key into `inventory_type`.
  final int? inventoryTypeId;

  /// e.g. Finished Goods / Raw Material / Consumable. Resolved from
  /// `inventory_type` for display, also stored as a snapshot.
  final String inventoryType;

  /// Foreign key into `product_category`.
  final int? categoryId;

  /// Category name — resolved from `product_category` for display, also
  /// stored as a snapshot.
  final String category;
  final bool isActive;

  factory StockItemModel.fromMap(Map<String, dynamic> map) {
    return StockItemModel(
      id: map['id'] as int?,
      barcode: (map['barcode'] as String?) ?? '',
      name: (map['name'] as String?) ?? '',
      sku: (map['sku'] as String?) ?? '',
      salePrice: _toDouble(map['sale_price']),
      purchasePrice: _toDouble(map['purchase_price']),
      quantity: _toDouble(map['quantity']),
      discount: _toDouble(map['discount']),
      tax: _toDouble(map['tax']),
      expiryDate: _toDate(map['expiry_date']),
      unit: (map['unit'] as String?) ?? 'pcs',
      companyId: map['company_id'] as int?,
      companyName: (map['company_name'] as String?) ?? '',
      inventoryTypeId: map['inventory_type_id'] as int?,
      inventoryType: (map['inventory_type'] as String?) ?? '',
      categoryId: map['category_id'] as int?,
      category: (map['category'] as String?) ?? '',
      isActive: (map['is_active'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'barcode': barcode,
        'name': name,
        'sku': sku,
        'sale_price': salePrice,
        'purchase_price': purchasePrice,
        'quantity': quantity,
        'discount': discount,
        'tax': tax,
        'expiry_date': expiryDate,
        'unit': unit,
        'company_id': companyId,
        'company_name': companyName,
        'inventory_type_id': inventoryTypeId,
        'inventory_type': inventoryType,
        'category_id': categoryId,
        'category': category,
        'is_active': isActive,
      };

  StockItemModel copyWith({
    int? id,
    String? barcode,
    String? name,
    String? sku,
    double? salePrice,
    double? purchasePrice,
    double? quantity,
    double? discount,
    double? tax,
    Object? expiryDate = _sentinel,
    String? unit,
    Object? companyId = _sentinel,
    String? companyName,
    Object? inventoryTypeId = _sentinel,
    String? inventoryType,
    Object? categoryId = _sentinel,
    String? category,
    bool? isActive,
  }) {
    return StockItemModel(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      salePrice: salePrice ?? this.salePrice,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      quantity: quantity ?? this.quantity,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
      expiryDate: identical(expiryDate, _sentinel)
          ? this.expiryDate
          : expiryDate as DateTime?,
      unit: unit ?? this.unit,
      companyId: identical(companyId, _sentinel)
          ? this.companyId
          : companyId as int?,
      companyName: companyName ?? this.companyName,
      inventoryTypeId: identical(inventoryTypeId, _sentinel)
          ? this.inventoryTypeId
          : inventoryTypeId as int?,
      inventoryType: inventoryType ?? this.inventoryType,
      categoryId: identical(categoryId, _sentinel)
          ? this.categoryId
          : categoryId as int?,
      category: category ?? this.category,
      isActive: isActive ?? this.isActive,
    );
  }

  static const Object _sentinel = Object();

  static double _toDouble(Object? v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static DateTime? _toDate(Object? v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }
}
