import '../../../../config/format.dart';
import '../../../../shared/export/export_doc.dart';
import '../../data/model/reports_model.dart';
import '../provider/reports_provider.dart';

/// Snapshots whichever report is on screen into an [ExportDoc]. Returns `null`
/// when the active report has no data.
ExportDoc? buildReportExport(ReportsProvider p) {
  final range = '${Fmt.date(p.range.start)} to ${Fmt.date(p.range.end)}';
  final tables = <ExportTable>[];
  final String name;

  switch (p.type) {
    case ReportType.sale:
      name = 'Sale Report';
      final rows = p.saleRows;
      if (rows.isEmpty) return null;
      tables.add(ExportTable(
        heading: 'Invoices',
        columns: const [
          'Invoice No.', 'Date', 'Customer', 'Total Discount', 'Sub Total',
          'Total Amount'
        ],
        rows: [
          for (final i in rows)
            [
              i.invoiceNo,
              Fmt.date(i.date),
              i.customer,
              Fmt.money(i.discount),
              Fmt.money(i.subtotal),
              Fmt.money(i.grandTotal),
            ],
        ],
      ));
      tables.add(_lineItems(
        'Line items',
        [for (final i in rows) (i.invoiceNo, i.items)],
      ));

    case ReportType.saleReturn:
      name = 'Sale Return Report';
      final rows = p.saleReturnRows;
      if (rows.isEmpty) return null;
      tables.add(ExportTable(
        heading: 'Returns',
        columns: const [
          'Return No.', 'Date', 'Customer', 'Qty', 'Return Value'
        ],
        rows: [
          for (final i in rows)
            [
              i.invoiceNo,
              Fmt.date(i.date),
              i.customer,
              _qty(i.quantity),
              Fmt.money(i.grandTotal),
            ],
        ],
      ));
      tables.add(_lineItems(
        'Line items',
        [for (final i in rows) (i.invoiceNo, i.items)],
      ));

    case ReportType.saleExchange:
      name = 'Sale Exchange Report';
      final rows = p.saleExchangeRows;
      if (rows.isEmpty) return null;
      tables.add(ExportTable(
        heading: 'Exchanges',
        columns: const [
          'Exchange No.', 'Date', 'Against Invoice', 'Customer', 'Old Total',
          'New Total', 'Difference'
        ],
        rows: [
          for (final e in rows)
            [
              e.exchangeNo,
              Fmt.date(e.date),
              e.invoiceNo,
              e.customer,
              Fmt.money(e.oldTotal),
              Fmt.money(e.newTotal),
              Fmt.money(e.difference),
            ],
        ],
      ));
      tables.add(ExportTable(
        heading: 'Moved lines',
        columns: const [
          'Exchange No.', 'Direction', 'Product', 'Qty', 'Price', 'Amount'
        ],
        rows: [
          for (final e in rows)
            for (final l in e.lines)
              [
                e.exchangeNo,
                l.isOut ? 'Returned' : 'Added',
                l.productName,
                '${_qty(l.quantity)} ${l.unit}',
                Fmt.money(l.salePrice),
                Fmt.money(l.lineTotal),
              ],
        ],
      ));

    case ReportType.purchase:
      name = 'Purchase Report';
      final data = p.purchaseData;
      if (data.purchases.isEmpty && data.returns.isEmpty) return null;
      tables.add(ExportTable(
        heading: 'Purchase Invoices',
        columns: const [
          'Invoice No.', 'Date', 'Supplier', 'Discount', 'Sub Total',
          'Total Amount'
        ],
        rows: [
          for (final i in data.purchases)
            [
              i.invoiceNo,
              Fmt.date(i.date),
              i.supplier,
              Fmt.money(i.discount),
              Fmt.money(i.subtotal),
              Fmt.money(i.grandTotal),
            ],
        ],
      ));
      if (data.purchases.isNotEmpty) {
        tables.add(_lineItems(
          'Line items',
          [for (final i in data.purchases) (i.invoiceNo, i.items)],
          rateHead: 'Cost',
        ));
      }
      if (data.returns.isNotEmpty) {
        tables.add(ExportTable(
          heading: 'Purchase Returns',
          columns: const ['Return No.', 'Date', 'Supplier', 'Qty', 'Value'],
          rows: [
            for (final r in data.returns)
              [
                r.invoiceNo,
                Fmt.date(r.date),
                r.party,
                _qty(r.quantity),
                Fmt.money(r.grandTotal),
              ],
          ],
        ));
      }

    case ReportType.category:
      name = 'Category-wise Report';
      final rows = p.categoryRows;
      if (rows.isEmpty) return null;
      tables.add(ExportTable(
        heading: 'Categories',
        columns: const [
          'Category', 'Qty', 'Sale value', 'Cost', 'Profit', 'Margin %'
        ],
        rows: [
          for (final r in rows)
            [
              r.category,
              _qty(r.quantity),
              Fmt.money(r.saleValue),
              Fmt.money(r.cost),
              Fmt.money(r.profit),
              r.margin.toStringAsFixed(1),
            ],
        ],
      ));
      tables.add(ExportTable(
        heading: 'Products',
        columns: const [
          'Category', 'Product', 'Qty', 'Sale', 'Cost', 'Profit'
        ],
        rows: [
          for (final r in rows)
            for (final it in r.items)
              [
                r.category,
                it.product,
                _qty(it.quantity),
                Fmt.money(it.saleValue),
                Fmt.money(it.cost),
                Fmt.money(it.profit),
              ],
        ],
      ));

    case ReportType.stock:
      name = 'Stock Report';
      final rows = p.stockRows;
      if (rows.isEmpty) return null;
      tables.add(ExportTable(
        heading: 'Stock movement',
        columns: const [
          'Product', 'Opening', 'Purchased', 'Sold', 'Sale Ret.',
          'Purch. Ret.', 'Closing'
        ],
        rows: [
          for (final r in rows)
            [
              r.product,
              _qty(r.opening),
              _qty(r.purchased),
              _qty(r.sold),
              _qty(r.saleReturned),
              _qty(r.purchaseReturned),
              _qty(r.closing),
            ],
        ],
      ));

    case ReportType.expense:
      name = 'Expense Report';
      final rows = p.expenseRows;
      if (rows.isEmpty) return null;
      tables.add(ExportTable(
        heading: 'Expenses',
        columns: const ['Date', 'Head', 'Amount', 'Mode', 'Description'],
        rows: [
          for (final r in rows)
            [
              Fmt.date(r.date),
              r.head,
              Fmt.money(r.amount),
              r.paymentMode,
              r.description,
            ],
        ],
      ));

    case ReportType.profitLoss:
      name = 'Profit and Loss';
      final pl = p.profitLoss;
      tables.add(ExportTable(
        heading: 'Summary',
        columns: const ['Line', 'Amount'],
        rows: [
          ['Gross Sales', Fmt.money(pl.grossSales)],
          ['Less: Sale Returns', Fmt.money(-pl.saleReturns)],
          ['Net Sales', Fmt.money(pl.netSales)],
          ['Less: Cost of Goods Sold', Fmt.money(-pl.cogs)],
          ['Gross Profit', Fmt.money(pl.grossProfit)],
          ['Less: Expenses', Fmt.money(-pl.expenses)],
          ['Net Profit', Fmt.money(pl.netProfit)],
        ],
      ));
  }

  return ExportDoc(
    title: '$name $range',
    subtitle: '$name  ·  $range',
    tables: tables,
  );
}

ExportTable _lineItems(
  String heading,
  List<(String, List<LineReportRow>)> invoices, {
  String rateHead = 'Rate',
}) {
  return ExportTable(
    heading: heading,
    columns: ['Invoice No.', 'Product', 'Qty', rateHead, 'Disc', 'Amount'],
    rows: [
      for (final (no, items) in invoices)
        for (final it in items)
          [
            no,
            it.product,
            '${_qty(it.quantity)} ${it.unit}',
            Fmt.money(it.price),
            it.discount == 0 ? '0' : Fmt.money(it.discount),
            Fmt.money(it.lineTotal),
          ],
    ],
  );
}

String _qty(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
