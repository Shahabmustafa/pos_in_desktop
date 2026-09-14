/// The reports the Reports screen can show.
enum ReportType {
  sale('Sale'),
  saleReturn('Sale Return'),
  saleExchange('Sale Exchange'),
  purchase('Purchase & Return'),
  stock('Stock'),
  category('Category-wise'),
  expense('Expense'),
  profitLoss('Profit & Loss');

  const ReportType(this.label);

  final String label;
}

/// One stock movement for a product (fills the Stock-report detail panel).
class StockMovement {
  const StockMovement({
    required this.date,
    required this.docNo,
    required this.type,
    required this.quantity,
    required this.inbound,
    this.party = '',
    this.price = 0,
    this.amount = 0,
  });

  final DateTime date;
  final String docNo;

  /// 'Purchase' | 'Sale' | 'Sale Return' | 'Purchase Return'.
  final String type;
  final double quantity;

  /// true when the movement adds to stock (purchase, sale return).
  final bool inbound;

  /// Customer name (sale / sale return) or supplier name (purchase / purchase
  /// return) on the document this movement came from.
  final String party;

  /// Unit rate on the line (sale price for a sale, cost for a purchase).
  final double price;

  /// Line total on the document line.
  final double amount;

  /// Signed effect on `stock_item.quantity`.
  double get delta => inbound ? quantity : -quantity;
}

/// One product row in the Stock report: how much it moved in the period and
/// what it opened / closed at.
class StockReportRow {
  const StockReportRow({
    required this.productId,
    required this.product,
    required this.unit,
    required this.closing,
    this.movements = const [],
  });

  final int? productId;
  final String product;
  final String unit;

  /// Current `stock_item.quantity` (a snapshot — not date-bounded).
  final double closing;
  final List<StockMovement> movements;

  double _sum(String t) =>
      movements.where((m) => m.type == t).fold(0.0, (a, m) => a + m.quantity);

  double get purchased => _sum('Purchase');
  double get sold => _sum('Sale');
  double get saleReturned => _sum('Sale Return');
  double get purchaseReturned => _sum('Purchase Return');

  /// Net change over the period (+purchase −sale +sale-return −purchase-return).
  double get netChange =>
      purchased - sold + saleReturned - purchaseReturned;

  /// Stock at the start of the period, worked back from [closing].
  double get opening => closing - netChange;

  bool get hasMovement => movements.isNotEmpty;
}

/// One product line shown in a right-hand detail panel (sale / sale return /
/// purchase invoice items).
class LineReportRow {
  const LineReportRow({
    required this.product,
    required this.unit,
    required this.quantity,
    required this.price,
    required this.discount,
    required this.lineTotal,
  });

  final String product;
  final String unit;
  final double quantity;

  /// Unit price (sale price for a sale line, purchase price for a purchase line).
  final double price;

  /// Discount value on the line (percentage + any flat amount).
  final double discount;
  final double lineTotal;

  factory LineReportRow.fromMap(Map<String, dynamic> m) {
    final qty = _d(m['quantity']);
    final price = _d(m['price']);
    final gross = qty * price;
    final disc = (gross * _d(m['discount']) / 100 + _d(m['discount_flat']))
        .clamp(0, gross);
    return LineReportRow(
      product: (m['product_name'] as String?)?.trim().isNotEmpty == true
          ? (m['product_name'] as String).trim()
          : '(unnamed)',
      unit: (m['unit'] as String?)?.trim() ?? 'pcs',
      quantity: qty,
      price: price,
      discount: disc.toDouble(),
      lineTotal: _d(m['line_total']),
    );
  }
}

/// One invoice row in the Sale report; [items] fill the detail panel.
class SaleReportInvoice {
  const SaleReportInvoice({
    required this.id,
    required this.invoiceNo,
    required this.date,
    required this.customer,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.grandTotal,
    required this.items,
  });

  /// Row id in `sale_invoice` — used to reprint the invoice from the report.
  final int id;
  final String invoiceNo;
  final DateTime date;
  final String customer;
  final double subtotal;
  final double discount;
  final double tax;
  final double grandTotal;
  final List<LineReportRow> items;

  factory SaleReportInvoice.fromMap(
    Map<String, dynamic> m, {
    List<LineReportRow> items = const [],
  }) {
    return SaleReportInvoice(
      id: m['id'] as int,
      invoiceNo: _no(m['invoice_no'], m['id']),
      date: _date(m['invoice_date']),
      customer: (m['customer_name'] as String?)?.trim() ?? '',
      subtotal: _d(m['subtotal']),
      discount: _d(m['discount_total']),
      tax: _d(m['tax_total']),
      grandTotal: _d(m['grand_total']),
      items: items,
    );
  }
}

/// One invoice row in the Sale Return report; [items] fill the detail panel.
class SaleReturnReportInvoice {
  const SaleReturnReportInvoice({
    required this.invoiceNo,
    required this.date,
    required this.customer,
    required this.quantity,
    required this.grandTotal,
    required this.items,
  });

  final String invoiceNo;
  final DateTime date;
  final String customer;
  final double quantity;
  final double grandTotal;
  final List<LineReportRow> items;

  factory SaleReturnReportInvoice.fromMap(
    Map<String, dynamic> m, {
    List<LineReportRow> items = const [],
  }) {
    return SaleReturnReportInvoice(
      invoiceNo: _no(m['invoice_no'], m['id']),
      date: _date(m['return_date']),
      customer: (m['customer_name'] as String?)?.trim() ?? '',
      quantity: _d(m['qty']),
      grandTotal: _d(m['grand_total']),
      items: items,
    );
  }
}

/// One invoice row in the Purchase report; [items] fill the detail panel.
class PurchaseReportInvoice {
  const PurchaseReportInvoice({
    required this.invoiceNo,
    required this.date,
    required this.supplier,
    required this.subtotal,
    required this.discount,
    required this.tax,
    required this.grandTotal,
    required this.items,
  });

  final String invoiceNo;
  final DateTime date;
  final String supplier;
  final double subtotal;
  final double discount;
  final double tax;
  final double grandTotal;
  final List<LineReportRow> items;

  factory PurchaseReportInvoice.fromMap(
    Map<String, dynamic> m, {
    List<LineReportRow> items = const [],
  }) {
    return PurchaseReportInvoice(
      invoiceNo: _no(m['invoice_no'], m['id']),
      date: _date(m['invoice_date']),
      supplier: (m['company_name'] as String?)?.trim() ?? '',
      subtotal: _d(m['subtotal']),
      discount: _d(m['discount_total']),
      tax: _d(m['tax_total']),
      grandTotal: _d(m['grand_total']),
      items: items,
    );
  }
}

/// A purchase-return row (no detail panel — quantity + value only).
class ReturnReportRow {
  const ReturnReportRow({
    required this.invoiceNo,
    required this.date,
    required this.party,
    required this.quantity,
    required this.grandTotal,
  });

  final String invoiceNo;
  final DateTime date;
  final String party;
  final double quantity;
  final double grandTotal;

  factory ReturnReportRow.fromMap(Map<String, dynamic> m) {
    return ReturnReportRow(
      invoiceNo: _no(m['invoice_no'], m['id']),
      date: _date(m['return_date']),
      party: (m['party'] as String?)?.trim() ?? '',
      quantity: _d(m['qty']),
      grandTotal: _d(m['grand_total']),
    );
  }
}

/// One product inside a category, shown in the Category-report detail panel.
class CategoryProductRow {
  const CategoryProductRow({
    required this.product,
    required this.quantity,
    required this.saleValue,
    required this.cost,
  });

  final String product;
  final double quantity;
  final double saleValue;
  final double cost;

  double get profit => saleValue - cost;

  factory CategoryProductRow.fromMap(Map<String, dynamic> m) {
    return CategoryProductRow(
      product: (m['product_name'] as String?)?.trim().isNotEmpty == true
          ? (m['product_name'] as String).trim()
          : '(unnamed)',
      quantity: _d(m['qty']),
      saleValue: _d(m['sale_value']),
      cost: _d(m['cost']),
    );
  }
}

/// One product-category row in the Category-wise report; [items] fill the
/// detail panel.
class CategoryReportRow {
  const CategoryReportRow({
    required this.category,
    required this.quantity,
    required this.saleValue,
    required this.cost,
    this.items = const [],
  });

  final String category;
  final double quantity;
  final double saleValue;
  final double cost;
  final List<CategoryProductRow> items;

  double get profit => saleValue - cost;
  double get margin => saleValue == 0 ? 0 : profit / saleValue * 100;

  factory CategoryReportRow.fromMap(
    Map<String, dynamic> m, {
    List<CategoryProductRow> items = const [],
  }) {
    return CategoryReportRow(
      category: (m['category'] as String?)?.trim().isNotEmpty == true
          ? (m['category'] as String).trim()
          : '(uncategorised)',
      quantity: _d(m['qty']),
      saleValue: _d(m['sale_value']),
      cost: _d(m['cost']),
      items: items,
    );
  }
}

/// One entry in the Expense report.
class ExpenseReportRow {
  const ExpenseReportRow({
    required this.date,
    required this.head,
    required this.amount,
    required this.paymentMode,
    required this.description,
  });

  final DateTime date;
  final String head;
  final double amount;
  final String paymentMode;
  final String description;

  factory ExpenseReportRow.fromMap(Map<String, dynamic> m) {
    return ExpenseReportRow(
      date: _date(m['entry_date']),
      head: (m['head'] as String?)?.trim() ?? '',
      amount: _d(m['amount']),
      paymentMode: (m['payment_mode'] as String?)?.trim() ?? '',
      description: (m['description'] as String?)?.trim() ?? '',
    );
  }
}

/// The Profit & Loss summary for a period, plus the lists behind each figure
/// (the "View" drill-downs).
class ProfitLossReport {
  const ProfitLossReport({
    required this.cogs,
    this.saleInvoices = const [],
    this.saleReturnInvoices = const [],
    this.expenseEntries = const [],
  });

  /// Cost of goods sold: `SUM(quantity * purchase_price)` on sold lines.
  final double cogs;

  final List<SaleReportInvoice> saleInvoices;
  final List<SaleReturnReportInvoice> saleReturnInvoices;
  final List<ExpenseReportRow> expenseEntries;

  double get grossSales =>
      saleInvoices.fold(0, (a, i) => a + i.grandTotal);
  double get saleReturns =>
      saleReturnInvoices.fold(0, (a, i) => a + i.grandTotal);
  double get expenses => expenseEntries.fold(0, (a, e) => a + e.amount);

  double get netSales => grossSales - saleReturns;
  double get grossProfit => netSales - cogs;
  double get netProfit => grossProfit - expenses;

  static const ProfitLossReport empty = ProfitLossReport(cogs: 0);
}

/// Purchases + purchase returns for the period.
class PurchaseReportData {
  const PurchaseReportData({required this.purchases, required this.returns});

  final List<PurchaseReportInvoice> purchases;
  final List<ReturnReportRow> returns;

  double get purchaseTotal => purchases.fold(0, (a, r) => a + r.grandTotal);
  double get returnTotal => returns.fold(0, (a, r) => a + r.grandTotal);
  double get netPurchase => purchaseTotal - returnTotal;

  static const PurchaseReportData empty =
      PurchaseReportData(purchases: [], returns: []);
}

String _no(Object? invoiceNo, Object? id) =>
    (invoiceNo as String?)?.trim().isNotEmpty == true
        ? (invoiceNo as String).trim()
        : '#$id';

double _d(Object? v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

DateTime _date(Object? v) {
  if (v is DateTime) return v;
  return DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
}
