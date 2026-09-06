/// One line moved by an exchange: [direction] 'out' = returned off the invoice,
/// 'in' = newly added.
class SaleExchangeLine {
  const SaleExchangeLine({
    required this.direction,
    required this.productName,
    required this.unit,
    required this.quantity,
    required this.salePrice,
    required this.lineTotal,
  });

  final String direction; // 'out' | 'in'
  final String productName;
  final String unit;
  final double quantity;
  final double salePrice;
  final double lineTotal;

  bool get isOut => direction == 'out';

  factory SaleExchangeLine.fromMap(Map<String, dynamic> m) {
    return SaleExchangeLine(
      direction: (m['direction'] as String?) == 'out' ? 'out' : 'in',
      productName: (m['product_name'] as String?)?.trim().isNotEmpty == true
          ? (m['product_name'] as String).trim()
          : '(unnamed)',
      unit: (m['unit'] as String?)?.trim() ?? 'pcs',
      quantity: _d(m['quantity']),
      salePrice: _d(m['sale_price']),
      lineTotal: _d(m['line_total']),
    );
  }
}

/// One recorded exchange (a log entry for Reports).
class SaleExchangeRecord {
  const SaleExchangeRecord({
    required this.exchangeNo,
    required this.date,
    required this.invoiceNo,
    required this.customer,
    required this.oldTotal,
    required this.newTotal,
    required this.lines,
  });

  final String exchangeNo;
  final DateTime date;

  /// The sale invoice this exchange was made against.
  final String invoiceNo;
  final String customer;
  final double oldTotal;
  final double newTotal;
  final List<SaleExchangeLine> lines;

  double get difference => newTotal - oldTotal;

  Iterable<SaleExchangeLine> get outLines => lines.where((l) => l.isOut);
  Iterable<SaleExchangeLine> get inLines => lines.where((l) => !l.isOut);

  factory SaleExchangeRecord.fromMap(
    Map<String, dynamic> m, {
    List<SaleExchangeLine> lines = const [],
  }) {
    return SaleExchangeRecord(
      exchangeNo: (m['exchange_no'] as String?)?.trim().isNotEmpty == true
          ? (m['exchange_no'] as String).trim()
          : '#${m['id']}',
      date: _date(m['exchange_date']),
      invoiceNo: (m['sale_invoice_no'] as String?)?.trim() ?? '',
      customer: (m['customer_name'] as String?)?.trim() ?? '',
      oldTotal: _d(m['old_total']),
      newTotal: _d(m['new_total']),
      lines: lines,
    );
  }
}

double _d(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

DateTime _date(Object? v) {
  if (v is DateTime) return v;
  return DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
}
