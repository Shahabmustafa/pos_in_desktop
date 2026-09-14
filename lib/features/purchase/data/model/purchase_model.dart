/// A single product line on a purchase invoice.
class PurchaseItemModel {
  const PurchaseItemModel({
    this.id,
    this.productId,
    this.productName = '',
    this.barcode = '',
    this.unit = 'pcs',
    this.quantity = 1,
    this.purchasePrice = 0,
    this.salePrice = 0,
    this.discount = 0,
    this.tax = 0,
  });

  final int? id;

  /// Foreign key into `stock_item`. `null` for a free-typed line.
  final int? productId;

  /// Product name snapshot (also resolved from `stock_item` for display).
  final String productName;
  final String barcode;
  final String unit;
  final double quantity;
  final double purchasePrice;

  /// Selling price captured on this line (for record only — does not change
  /// the product's stock sale price).
  final double salePrice;

  /// Discount percentage on this line.
  final double discount;

  /// Tax percentage on this line.
  final double tax;

  /// quantity x price, before discount / tax.
  double get gross => quantity * purchasePrice;

  double get discountAmount => gross * discount / 100;

  double get taxAmount => (gross - discountAmount) * tax / 100;

  /// What this line actually adds to the invoice total.
  double get lineTotal => gross - discountAmount + taxAmount;

  factory PurchaseItemModel.fromMap(Map<String, dynamic> map) {
    return PurchaseItemModel(
      id: map['id'] as int?,
      productId: map['product_id'] as int?,
      productName: (map['product_name'] as String?) ?? '',
      barcode: (map['barcode'] as String?) ?? '',
      unit: (map['unit'] as String?) ?? 'pcs',
      quantity: _toDouble(map['quantity']),
      purchasePrice: _toDouble(map['purchase_price']),
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
        'unit': unit,
        'quantity': quantity,
        'purchase_price': purchasePrice,
        'sale_price': salePrice,
        'discount': discount,
        'tax': tax,
        'line_total': lineTotal,
      };

  PurchaseItemModel copyWith({
    int? id,
    int? productId,
    String? productName,
    String? barcode,
    String? unit,
    double? quantity,
    double? purchasePrice,
    double? salePrice,
    double? discount,
    double? tax,
  }) {
    return PurchaseItemModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      barcode: barcode ?? this.barcode,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      salePrice: salePrice ?? this.salePrice,
      discount: discount ?? this.discount,
      tax: tax ?? this.tax,
    );
  }

  static double _toDouble(Object? v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

/// A purchase invoice: a header (supplier company, number, date) plus one or
/// more [items].
class PurchaseModel {
  const PurchaseModel({
    this.id,
    this.invoiceNo = '',
    required this.date,
    this.companyId,
    this.companyName = '',
    this.reference = '',
    this.notes = '',
    this.amountPaid = 0,
    this.items = const [],
  });

  final int? id;
  final String invoiceNo;
  final DateTime date;

  /// Foreign key into `company` — the supplier.
  final int? companyId;
  final String companyName;

  /// Supplier bill / DC number.
  final String reference;
  final String notes;

  /// Cash paid to the supplier at purchase time. The rest of [grandTotal] is
  /// left on the company's running payable (computed live — see
  /// `PurchaseDataSource.fetchCompanies`).
  final double amountPaid;

  final List<PurchaseItemModel> items;

  double get subtotal => items.fold(0, (a, i) => a + i.gross);
  double get discountTotal => items.fold(0, (a, i) => a + i.discountAmount);
  double get taxTotal => items.fold(0, (a, i) => a + i.taxAmount);
  double get grandTotal => items.fold(0, (a, i) => a + i.lineTotal);
  int get itemCount => items.length;

  /// Portion of this invoice left on the company's payable.
  double get balanceDue => grandTotal - amountPaid;

  factory PurchaseModel.fromMap(
    Map<String, dynamic> map, {
    List<PurchaseItemModel> items = const [],
  }) {
    return PurchaseModel(
      id: map['id'] as int?,
      invoiceNo: (map['invoice_no'] as String?) ?? '',
      date: _toDate(map['invoice_date']),
      companyId: map['company_id'] as int?,
      companyName: (map['company_name'] as String?) ?? '',
      reference: (map['reference'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
      amountPaid: _toDouble(map['amount_paid']),
      items: items,
    );
  }

  /// Header columns for `purchase`. The totals are derived from [items] so
  /// they stay consistent with the lines.
  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'invoice_no': invoiceNo,
        'invoice_date': date,
        'company_id': companyId,
        'company_name': companyName,
        'reference': reference,
        'notes': notes,
        'amount_paid': amountPaid,
        'subtotal': subtotal,
        'discount_total': discountTotal,
        'tax_total': taxTotal,
        'grand_total': grandTotal,
      };

  PurchaseModel copyWith({
    int? id,
    String? invoiceNo,
    DateTime? date,
    int? companyId,
    String? companyName,
    String? reference,
    String? notes,
    double? amountPaid,
    List<PurchaseItemModel>? items,
  }) {
    return PurchaseModel(
      id: id ?? this.id,
      invoiceNo: invoiceNo ?? this.invoiceNo,
      date: date ?? this.date,
      companyId: companyId ?? this.companyId,
      companyName: companyName ?? this.companyName,
      reference: reference ?? this.reference,
      notes: notes ?? this.notes,
      amountPaid: amountPaid ?? this.amountPaid,
      items: items ?? this.items,
    );
  }

  static DateTime _toDate(Object? v) {
    if (v is DateTime) return v;
    return DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
  }

  static double _toDouble(Object? v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}
