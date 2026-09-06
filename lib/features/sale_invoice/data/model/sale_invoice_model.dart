/// A single product line on a sale invoice.
class SaleInvoiceItemModel {
  const SaleInvoiceItemModel({
    this.id,
    this.productId,
    this.productName = '',
    this.barcode = '',
    this.unit = 'pcs',
    this.quantity = 1,
    this.salePrice = 0,
    this.purchasePrice = 0,
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

  /// Price per unit charged to the customer.
  final double salePrice;

  /// Cost (purchase) price per unit, snapshotted at sale time so reports can
  /// work out profit even if the product's cost changes later.
  final double purchasePrice;

  /// Discount percentage on this line.
  final double discount;

  /// Flat (rupee) discount on this line, on top of the [discount] percentage.
  final double discountFlat;

  /// Tax percentage on this line.
  final double tax;

  /// quantity x price, before discount / tax.
  double get gross => quantity * salePrice;

  /// Total discount value on this line (percentage + flat), capped at [gross].
  double get discountAmount {
    final d = gross * discount / 100 + discountFlat;
    if (d < 0) return 0;
    return d > gross ? gross : d;
  }

  double get taxAmount => (gross - discountAmount) * tax / 100;

  /// What this line adds to the invoice total.
  double get lineTotal => gross - discountAmount + taxAmount;

  /// Cost of goods on this line.
  double get costTotal => quantity * purchasePrice;

  /// Line profit (revenue − cost).
  double get profit => lineTotal - costTotal;

  factory SaleInvoiceItemModel.fromMap(Map<String, dynamic> map) {
    return SaleInvoiceItemModel(
      id: map['id'] as int?,
      productId: map['product_id'] as int?,
      productName: (map['product_name'] as String?) ?? '',
      barcode: (map['barcode'] as String?) ?? '',
      unit: (map['unit'] as String?) ?? 'pcs',
      quantity: _toDouble(map['quantity']),
      salePrice: _toDouble(map['sale_price']),
      purchasePrice: _toDouble(map['purchase_price']),
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
        'purchase_price': purchasePrice,
        'discount': discount,
        'discount_flat': discountFlat,
        'tax': tax,
        'line_total': lineTotal,
      };

  SaleInvoiceItemModel copyWith({
    int? id,
    int? productId,
    String? productName,
    String? barcode,
    String? unit,
    double? quantity,
    double? salePrice,
    double? purchasePrice,
    double? discount,
    double? discountFlat,
    double? tax,
  }) {
    return SaleInvoiceItemModel(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      barcode: barcode ?? this.barcode,
      unit: unit ?? this.unit,
      quantity: quantity ?? this.quantity,
      salePrice: salePrice ?? this.salePrice,
      purchasePrice: purchasePrice ?? this.purchasePrice,
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

/// A sale invoice: a header (customer, number, date) plus one or more [items].
/// Discounts are per-line only (a percentage and a flat amount each).
class SaleInvoiceModel {
  const SaleInvoiceModel({
    this.id,
    this.invoiceNo = '',
    required this.date,
    this.customerId,
    this.customerName = '',
    this.notes = '',
    this.amountReceived = 0,
    this.bankHeadId,
    this.items = const [],
  });

  final int? id;
  final String invoiceNo;
  final DateTime date;

  /// Foreign key into `customer`.
  final int? customerId;
  final String customerName;
  final String notes;

  /// Bank account (`bank_head`) the received cash was deposited into, or `null`
  /// for a plain cash sale. Set → a `bank_entry` deposit is posted on save.
  final int? bankHeadId;

  /// Cash taken from the customer at the till. The rest of [grandTotal] is
  /// added to the customer's `opening_balance`.
  final double amountReceived;

  final List<SaleInvoiceItemModel> items;

  double get subtotal => items.fold(0, (a, i) => a + i.gross);
  double get discountTotal => items.fold(0, (a, i) => a + i.discountAmount);
  double get taxTotal => items.fold(0, (a, i) => a + i.taxAmount);
  double get grandTotal => items.fold(0, (a, i) => a + i.lineTotal);

  /// Portion of this invoice left on the customer's account.
  double get balanceDue => grandTotal - amountReceived;

  /// Total cost of goods sold on this invoice.
  double get costTotal => items.fold(0, (a, i) => a + i.costTotal);

  /// Invoice profit = what the customer pays (after discounts) − cost.
  double get profit => grandTotal - costTotal;

  int get itemCount => items.length;
  double get totalQuantity => items.fold(0, (a, i) => a + i.quantity);

  factory SaleInvoiceModel.fromMap(
    Map<String, dynamic> map, {
    List<SaleInvoiceItemModel> items = const [],
  }) {
    return SaleInvoiceModel(
      id: map['id'] as int?,
      invoiceNo: (map['invoice_no'] as String?) ?? '',
      date: _toDate(map['invoice_date']),
      customerId: map['customer_id'] as int?,
      customerName: (map['customer_name'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
      amountReceived: _toDouble(map['amount_received']),
      bankHeadId: map['bank_head_id'] as int?,
      items: items,
    );
  }

  /// Header columns for `sale_invoice`. Totals are derived from [items] so they
  /// stay consistent with the lines.
  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'invoice_no': invoiceNo,
        'invoice_date': date,
        'customer_id': customerId,
        'customer_name': customerName,
        'notes': notes,
        'amount_received': amountReceived,
        'bank_head_id': bankHeadId,
        'subtotal': subtotal,
        'discount_total': discountTotal,
        'tax_total': taxTotal,
        'grand_total': grandTotal,
      };

  SaleInvoiceModel copyWith({
    int? id,
    String? invoiceNo,
    DateTime? date,
    int? customerId,
    String? customerName,
    String? notes,
    double? amountReceived,
    int? bankHeadId,
    List<SaleInvoiceItemModel>? items,
  }) {
    return SaleInvoiceModel(
      id: id ?? this.id,
      invoiceNo: invoiceNo ?? this.invoiceNo,
      date: date ?? this.date,
      customerId: customerId ?? this.customerId,
      customerName: customerName ?? this.customerName,
      notes: notes ?? this.notes,
      amountReceived: amountReceived ?? this.amountReceived,
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
