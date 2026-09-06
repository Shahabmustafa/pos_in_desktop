import 'purchase_return_item_model.dart';

/// A purchase-return invoice: goods sent back to a supplier (company), with
/// one or more product lines.
class PurchaseReturnModel {
  const PurchaseReturnModel({
    this.id,
    this.invoiceNo = '',
    required this.returnDate,
    this.companyId,
    this.companyName = '',
    this.reference = '',
    this.remarks = '',
    this.items = const [],
  });

  final int? id;

  /// Human-facing number, e.g. `PR-000012`. Assigned on save.
  final String invoiceNo;
  final DateTime returnDate;

  /// Foreign key into `company` (the supplier).
  final int? companyId;
  final String companyName;

  /// Original purchase bill / GRN number this return is against.
  final String reference;
  final String remarks;
  final List<PurchaseReturnItemModel> items;

  double get subtotal => items.fold(0, (a, i) => a + i.gross);

  double get discountTotal => items.fold(0, (a, i) => a + i.discountAmount);

  double get taxTotal => items.fold(0, (a, i) => a + i.taxAmount);

  double get grandTotal => items.fold(0, (a, i) => a + i.lineTotal);

  int get itemCount => items.length;

  double get totalQuantity => items.fold(0, (a, i) => a + i.quantity);

  factory PurchaseReturnModel.fromMap(
    Map<String, dynamic> map, {
    List<PurchaseReturnItemModel> items = const [],
  }) {
    return PurchaseReturnModel(
      id: map['id'] as int?,
      invoiceNo: (map['invoice_no'] as String?) ?? '',
      returnDate: _toDate(map['return_date']),
      companyId: map['company_id'] as int?,
      companyName: (map['company_name'] as String?) ?? '',
      reference: (map['reference'] as String?) ?? '',
      remarks: (map['remarks'] as String?) ?? '',
      items: items,
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'invoice_no': invoiceNo,
        'return_date': returnDate,
        'company_id': companyId,
        'company_name': companyName,
        'reference': reference,
        'remarks': remarks,
        'subtotal': subtotal,
        'discount_total': discountTotal,
        'tax_total': taxTotal,
        'grand_total': grandTotal,
      };

  PurchaseReturnModel copyWith({
    int? id,
    String? invoiceNo,
    DateTime? returnDate,
    Object? companyId = _sentinel,
    String? companyName,
    String? reference,
    String? remarks,
    List<PurchaseReturnItemModel>? items,
  }) {
    return PurchaseReturnModel(
      id: id ?? this.id,
      invoiceNo: invoiceNo ?? this.invoiceNo,
      returnDate: returnDate ?? this.returnDate,
      companyId:
          identical(companyId, _sentinel) ? this.companyId : companyId as int?,
      companyName: companyName ?? this.companyName,
      reference: reference ?? this.reference,
      remarks: remarks ?? this.remarks,
      items: items ?? this.items,
    );
  }

  static const Object _sentinel = Object();

  static DateTime _toDate(Object? v) {
    if (v is DateTime) return v;
    return DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
  }
}

/// A product the user can pick onto a purchase-return line. Carries the
/// purchase price so a new line can be pre-filled.
class ProductOption {
  const ProductOption({
    required this.id,
    required this.name,
    this.barcode = '',
    this.purchasePrice = 0,
    this.salePrice = 0,
    this.tax = 0,
    this.quantity = 0,
  });

  final int id;
  final String name;
  final String barcode;
  final double purchasePrice;
  final double salePrice;
  final double tax;

  /// On-hand quantity in `stock_item`.
  final double quantity;

  factory ProductOption.fromMap(Map<String, dynamic> map) {
    return ProductOption(
      id: map['id'] as int,
      name: (map['name'] as String?) ?? '',
      barcode: (map['barcode'] as String?) ?? '',
      purchasePrice: _toDouble(map['purchase_price']),
      salePrice: _toDouble(map['sale_price']),
      tax: _toDouble(map['tax']),
      quantity: _toDouble(map['quantity']),
    );
  }

  @override
  bool operator ==(Object other) => other is ProductOption && other.id == id;

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

/// A `{id, name}` supplier option for the company picker.
class CompanyOption {
  const CompanyOption({required this.id, required this.name});

  final int id;
  final String name;

  factory CompanyOption.fromMap(Map<String, dynamic> map) => CompanyOption(
        id: map['id'] as int,
        name: (map['name'] as String?) ?? '',
      );

  @override
  bool operator ==(Object other) => other is CompanyOption && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => name;
}
