import 'dart:convert';

double _d(Object? v) {
  if (v is num) return v.toDouble();
  return double.tryParse('${v ?? ''}') ?? 0;
}

/// One parked cart line inside a [HeldSaleInvoiceModel].
class HeldSaleLineModel {
  const HeldSaleLineModel({
    required this.productId,
    this.productName = '',
    this.quantity = 1,
    this.price = 0,
    this.discount = 0,
    this.discountFlat = 0,
    this.tax = 0,
  });

  /// `stock_item` id. On resume the line is rebuilt from the live product, so a
  /// product deleted meanwhile is simply dropped.
  final int productId;
  final String productName;
  final double quantity;

  /// Unit sale price the operator had typed.
  final double price;
  final double discount;
  final double discountFlat;
  final double tax;

  double get lineTotal {
    final gross = quantity * price;
    final disc = (gross * discount / 100 + discountFlat).clamp(0, gross);
    return gross - disc + (gross - disc) * tax / 100;
  }

  factory HeldSaleLineModel.fromJson(Map<String, dynamic> j) => HeldSaleLineModel(
        productId: (j['product_id'] as num?)?.toInt() ?? 0,
        productName: (j['product_name'] as String?) ?? '',
        quantity: _d(j['quantity']),
        price: _d(j['price']),
        discount: _d(j['discount']),
        discountFlat: _d(j['discount_flat']),
        tax: _d(j['tax']),
      );

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'product_name': productName,
        'quantity': quantity,
        'price': price,
        'discount': discount,
        'discount_flat': discountFlat,
        'tax': tax,
      };
}

/// A held (parked) sale invoice: the whole cart saved so the till can serve the
/// next customer and resume this one later. Holding touches no stock — that
/// only moves when the invoice is actually saved.
class HeldSaleInvoiceModel {
  HeldSaleInvoiceModel({
    this.id,
    this.customerId,
    this.customerName = '',
    this.notes = '',
    this.bankHeadId,
    required this.date,
    this.heldBy = '',
    DateTime? heldAt,
    this.overallDiscount = 0,
    this.lines = const [],
  }) : heldAt = heldAt ?? DateTime.now();

  final int? id;
  final int? customerId;
  final String customerName;
  final String notes;
  final int? bankHeadId;
  final DateTime date;

  /// Username of whoever held it (for the resume list). May be empty.
  final String heldBy;
  final DateTime heldAt;

  /// Overall discount percentage on top of the lines' own discounts (see
  /// `SaleInvoiceModel.overallDiscount`), carried through hold / resume.
  final double overallDiscount;

  final List<HeldSaleLineModel> lines;

  int get itemCount => lines.length;

  double get subtotalAfterLineDiscounts => lines.fold(0, (a, l) {
        final gross = l.quantity * l.price;
        final disc = (gross * l.discount / 100 + l.discountFlat)
            .clamp(0, gross)
            .toDouble();
        return a + gross - disc;
      });

  double get overallDiscountAmount {
    final base = subtotalAfterLineDiscounts;
    final amt = base * overallDiscount / 100;
    if (amt < 0) return 0;
    return amt > base ? base : amt;
  }

  double get grandTotal =>
      lines.fold<double>(0, (a, l) => a + l.lineTotal) - overallDiscountAmount;

  String get title => customerName.trim().isEmpty ? 'Walk-in' : customerName;

  factory HeldSaleInvoiceModel.fromMap(Map<String, dynamic> map) {
    final raw = map['lines'];
    final decoded = raw is String
        ? (raw.trim().isEmpty ? const [] : jsonDecode(raw) as List)
        : (raw as List? ?? const []);
    return HeldSaleInvoiceModel(
      id: map['id'] as int?,
      customerId: map['customer_id'] as int?,
      customerName: (map['customer_name'] as String?) ?? '',
      notes: (map['notes'] as String?) ?? '',
      bankHeadId: map['bank_head_id'] as int?,
      date: _toDate(map['invoice_date']),
      heldBy: (map['held_by'] as String?) ?? '',
      heldAt: map['created_at'] is DateTime
          ? map['created_at'] as DateTime
          : DateTime.tryParse('${map['created_at'] ?? ''}'),
      overallDiscount: _d(map['overall_discount']),
      lines: [
        for (final e in decoded)
          HeldSaleLineModel.fromJson((e as Map).cast<String, dynamic>()),
      ],
    );
  }

  /// Columns for an insert. `lines` is a JSON string (stored in a TEXT column).
  Map<String, dynamic> toInsertParams() => {
        'customer_id': customerId,
        'customer_name': customerName,
        'notes': notes,
        'bank_head_id': bankHeadId,
        'invoice_date': date,
        'item_count': itemCount,
        'grand_total': grandTotal,
        'held_by': heldBy,
        'overall_discount': overallDiscount,
        'lines': jsonEncode([for (final l in lines) l.toJson()]),
      };

  static DateTime _toDate(Object? v) {
    if (v is DateTime) return v;
    return DateTime.tryParse('${v ?? ''}') ?? DateTime.now();
  }
}
