/// One product line on a sale-return invoice.
class SaleReturnItemModel {
  const SaleReturnItemModel({
    this.id,
    this.productId,
    this.productName = '',
    this.barcode = '',
    this.unit = 'pcs',
    this.quantity = 1,
    this.salePrice = 0,
    this.discount = 0,
    this.discountFlat = 0,
    this.tax = 0,
  });

  final int? id;

  /// Foreign key into `stock_item`. `null` for a free-typed line.
  final int? productId;
  final String productName;
  final String barcode;
  final String unit;
  final double quantity;

  /// Price per unit being credited back to the customer.
  final double salePrice;

  /// Discount percentage on this line.
  final double discount;

  /// Flat (rupee) discount on this line, carried over from the sale invoice
  /// line (pro-rated when only part of the line is returned).
  final double discountFlat;

  /// Tax percentage on this line.
  final double tax;

  double get gross => quantity * salePrice;

  double get discountAmount {
    final d = gross * discount / 100 + discountFlat;
    if (d < 0) return 0;
    return d > gross ? gross : d;
  }

  double get taxAmount => (gross - discountAmount) * tax / 100;

  /// What this line credits back, before the whole-invoice discount.
  double get lineTotal => gross - discountAmount + taxAmount;

  factory SaleReturnItemModel.fromMap(Map<String, dynamic> map) {
    return SaleReturnItemModel(
      id: map['id'] as int?,
      productId: map['product_id'] as int?,
      productName: (map['product_name'] as String?) ?? '',
      barcode: (map['barcode'] as String?) ?? '',
      unit: (map['unit'] as String?) ?? 'pcs',
      quantity: _toDouble(map['quantity']),
      salePrice: _toDouble(map['sale_price']),
      discount: _toDouble(map['discount']),
      discountFlat: _toDouble(map['discount_flat']),
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
        'sale_price': salePrice,
        'discount': discount,
        'discount_flat': discountFlat,
        'tax': tax,
        'line_total': lineTotal,
      };

  SaleReturnItemModel copyWith({
    int? id,
    int? productId,
    String? productName,
    String? barcode,
    String? unit,
    double? quantity,
    double? salePrice,
    double? discount,
    double? discountFlat,
    double? tax,
  }) {
    return SaleReturnItemModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      barcode: barcode ?? this.barcode,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      salePrice: salePrice ?? this.salePrice,
      discount: discount ?? this.discount,
      discountFlat: discountFlat ?? this.discountFlat,
      tax: tax ?? this.tax,
    );
  }

  static double _toDouble(Object? v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

/// A sale-return invoice: goods a customer brought back, with one or more
/// product lines. Discounts are per-line only.
class SaleReturnModel {
  const SaleReturnModel({
    this.id,
    this.invoiceNo = '',
    required this.returnDate,
    this.customerId,
    this.customerName = '',
    this.notes = '',
    this.amountPaid = 0,
    this.bankHeadId,
    this.items = const [],
  });

  final int? id;

  /// Human-facing number, e.g. `SR-000012`. Assigned on save.
  final String invoiceNo;
  final DateTime returnDate;

  /// Foreign key into `customer`.
  final int? customerId;
  final String customerName;
  final String notes;

  /// Cash paid back to the customer now. The rest of [grandTotal] is added to
  /// the customer's `opening_balance`.
  final double amountPaid;

  /// Bank account (`bank_head`) the refund was paid from, or `null`. Set → a
  /// `bank_entry` withdrawal is posted when the return is recorded.
  final int? bankHeadId;

  final List<SaleReturnItemModel> items;

  double get subtotal => items.fold(0, (a, i) => a + i.gross);
  double get discountTotal => items.fold(0, (a, i) => a + i.discountAmount);
  double get taxTotal => items.fold(0, (a, i) => a + i.taxAmount);
  double get grandTotal => items.fold(0, (a, i) => a + i.lineTotal);

  /// Portion of this return left on the customer's account.
  double get balanceDue => grandTotal - amountPaid;

  int get itemCount => items.length;
  double get totalQuantity => items.fold(0, (a, i) => a + i.quantity);

  factory SaleReturnModel.fromMap(
    Map<String, dynamic> map, {
    List<SaleReturnItemModel> items = const [],
  }) {
    return SaleReturnModel(
      id: map['id'] as int?,
      invoiceNo: (map['invoice_no'] as String?) ?? '',
      returnDate: _toDate(map['return_date']),
      customerId: map['customer_id'] as int?,
      customerName: (map['customer_name'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
      amountPaid: _toDouble(map['amount_paid']),
      bankHeadId: map['bank_head_id'] as int?,
      items: items,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'invoice_no': invoiceNo,
        'return_date': returnDate,
        'customer_id': customerId,
        'customer_name': customerName,
        'notes': notes,
        'amount_paid': amountPaid,
        'bank_head_id': bankHeadId,
        'subtotal': subtotal,
        'discount_total': discountTotal,
        'tax_total': taxTotal,
        'grand_total': grandTotal,
      };

  SaleReturnModel copyWith({
    int? id,
    String? invoiceNo,
    DateTime? returnDate,
    int? customerId,
    String? customerName,
    String? notes,
    double? amountPaid,
    int? bankHeadId,
    List<SaleReturnItemModel>? items,
  }) {
    return SaleReturnModel(
      id: id ?? this.id,
      invoiceNo: invoiceNo ?? this.invoiceNo,
      returnDate: returnDate ?? this.returnDate,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      notes: notes ?? this.notes,
      amountPaid: amountPaid ?? this.amountPaid,
      bankHeadId: bankHeadId ?? this.bankHeadId,
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
