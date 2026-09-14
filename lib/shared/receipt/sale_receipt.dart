import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../config/format.dart';
import '../../features/receipt_settings/data/model/receipt_settings_model.dart';
import '../../features/sale_invoice/data/model/sale_invoice_model.dart';

/// One printed line on an invoice.
class ReceiptLine {
  const ReceiptLine({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.discountAmount = 0,
    this.unit = '',
  });

  final String name;
  final double quantity;
  final double unitPrice;
  final double lineTotal;
  final double discountAmount;

  /// Selling unit (e.g. `pcs`, `kg`) — printed next to the quantity.
  final String unit;
}

/// An extra totals row printed under Subtotal / Discount / Tax (e.g. "Paid",
/// "Balance").
class ReceiptTotal {
  const ReceiptTotal(this.label, this.value, {this.bold = false});

  final String label;
  final double value;
  final bool bold;
}

/// Everything the generic A4 invoice needs — sale invoice, purchase, return
/// and exchange all build one of these.
class ReceiptData {
  const ReceiptData({
    required this.docType,
    required this.invoiceNo,
    required this.date,
    required this.partyLabel,
    required this.partyName,
    required this.lines,
    required this.subtotal,
    required this.discountTotal,
    required this.taxTotal,
    required this.grandTotal,
    this.grandTotalLabel = 'GRAND TOTAL',
    this.notes = '',
    this.extraInfo = const [],
    this.extraTotals = const [],
  });

  /// Printed under the shop header, e.g. `SALE INVOICE`, `PURCHASE RETURN`.
  final String docType;
  final String invoiceNo;
  final DateTime date;

  /// e.g. `Customer` / `Supplier`.
  final String partyLabel;
  final String partyName;

  final List<ReceiptLine> lines;
  final double subtotal;
  final double discountTotal;
  final double taxTotal;
  final double grandTotal;
  final String grandTotalLabel;

  /// Invoice notes. Printed under the info grid when non-empty and the
  /// "Invoice notes" toggle is on in Receipt Settings.
  final String notes;

  /// Extra `key: value` columns in the info grid (e.g. `Against: SI-000042`).
  final List<(String, String)> extraInfo;

  /// Extra totals rows under Tax (e.g. Paid / Balance).
  final List<ReceiptTotal> extraTotals;

  int get itemCount => lines.length;
  double get totalQuantity => lines.fold(0, (a, l) => a + l.quantity);
}

/// Builds an A4 invoice PDF for a saved [SaleInvoiceModel].
Future<Uint8List> buildSaleReceiptPdf(SaleInvoiceModel invoice) {
  return buildReceiptPdf(ReceiptData(
    docType: 'SALE INVOICE',
    invoiceNo: invoice.invoiceNo,
    date: invoice.date,
    partyLabel: 'Customer',
    partyName: invoice.customerName.isEmpty ? 'Walk-in' : invoice.customerName,
    lines: [
      for (final it in invoice.items)
        ReceiptLine(
          name: it.productName,
          quantity: it.quantity,
          unitPrice: it.salePrice,
          lineTotal: it.lineTotal,
          discountAmount: it.discountAmount,
          unit: it.unit,
        ),
    ],
    subtotal: invoice.subtotal,
    discountTotal: invoice.discountTotal,
    taxTotal: invoice.taxTotal,
    grandTotal: invoice.grandTotal,
    notes: invoice.notes,
    extraTotals: [
      ReceiptTotal('Paid', invoice.amountReceived),
      if (invoice.balanceDue.abs() > 0.009)
        ReceiptTotal('Balance', invoice.balanceDue, bold: true),
    ],
  ));
}

/// Builds an A4 tabular invoice PDF (shop header, an info grid, a bordered
/// item table and a totals block) from a ready-made [ReceiptData] — meant for
/// a plain A4 printer, no thermal printer required. Long item lists flow onto
/// extra pages automatically, repeating the shop header and table columns.
Future<Uint8List> buildReceiptPdf(ReceiptData data) async {
  // Built-in Helvetica — no network fetch, works fully offline.
  final doc = pw.Document();
  final theme = pw.ThemeData.withFont(
    base: pw.Font.helvetica(),
    bold: pw.Font.helveticaBold(),
  );

  // Shop header + which fields to print — configured on the Receipt Settings
  // screen, cached in ReceiptSettingsModel.current.
  final s = ReceiptSettingsModel.current;
  final dateStr = Fmt.date(data.date);
  final showDiscountCol =
      s.showItemDiscount && data.lines.any((l) => l.discountAmount > 0);

  pw.Widget header(pw.Context context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          if (s.showLogo && s.logo != null) ...[
            pw.Center(
              child: pw.Image(pw.MemoryImage(s.logo!),
                  height: 46, fit: pw.BoxFit.contain),
            ),
            pw.SizedBox(height: 4),
          ],
          if (s.businessName.trim().isNotEmpty)
            pw.Center(
              child: pw.Text(s.businessName,
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),
            ),
          if (s.businessAddress.trim().isNotEmpty)
            pw.Center(
                child: pw.Text(s.businessAddress,
                    style: _normal, textAlign: pw.TextAlign.center)),
          if (s.businessPhone.trim().isNotEmpty)
            pw.Center(child: pw.Text(s.businessPhone, style: _normal)),
          pw.SizedBox(height: 8),
          pw.Container(
            width: double.infinity,
            alignment: pw.Alignment.center,
            padding: const pw.EdgeInsets.symmetric(vertical: 5),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(width: 1),
                bottom: pw.BorderSide(width: 1),
              ),
            ),
            child: pw.Text(data.docType,
                style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 1)),
          ),
          pw.SizedBox(height: 8),
          _infoGrid(data, s, dateStr),
          if (s.showNotes && data.notes.trim().isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text('Notes: ${data.notes.trim()}', style: _small),
          ],
          pw.SizedBox(height: 10),
        ],
      );

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
      theme: theme,
      header: header,
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
            style: _tiny),
      ),
      build: (context) => [
        _itemsTable(context, data, showDiscountCol),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end,
          children: [
            pw.SizedBox(
              width: 220,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _totalRow('Subtotal', data.subtotal),
                  if (data.discountTotal > 0 && s.showDiscountTotal)
                    _totalRow('Discount', -data.discountTotal),
                  if (data.taxTotal > 0 && s.showTaxTotal)
                    _totalRow('Tax', data.taxTotal),
                  pw.Divider(height: 8, thickness: 0.75),
                  _totalRow(data.grandTotalLabel, data.grandTotal, bold: true),
                  if (s.showPaidBalance)
                    for (final t in data.extraTotals)
                      _totalRow(t.label, t.value, bold: t.bold),
                ],
              ),
            ),
          ],
        ),
        if (s.showFooter && s.footerText.trim().isNotEmpty) ...[
          pw.SizedBox(height: 20),
          pw.Center(
              child: pw.Text(s.footerText.trim(),
                  style: _normal, textAlign: pw.TextAlign.center)),
        ],
        if (s.showItemCount) ...[
          pw.SizedBox(height: 8),
          pw.Text(
              '${data.itemCount} item(s)  -  ${_num(data.totalQuantity)} unit(s)',
              style: _small),
        ],
      ],
    ),
  );

  return doc.save();
}

/// A small bordered header/value grid: party, invoice no., date, plus any
/// [ReceiptData.extraInfo] pairs (e.g. "Against: SI-000042" on a return).
pw.Widget _infoGrid(ReceiptData data, ReceiptSettingsModel s, String dateStr) {
  final headers = <String>[];
  final values = <String>[];

  if (s.showParty) {
    headers.add(data.partyLabel);
    values.add(data.partyName.isEmpty ? '-' : data.partyName);
  }
  if (s.showInvoiceNo) {
    headers.add(data.docType.contains('RETURN') ? 'Return No.' : 'Invoice No.');
    values.add(data.invoiceNo.isEmpty ? '-' : data.invoiceNo);
  }
  if (s.showDate) {
    headers.add('Dated');
    values.add(dateStr);
  }
  for (final info in data.extraInfo) {
    headers.add(info.$1);
    values.add(info.$2);
  }
  if (headers.isEmpty) return pw.SizedBox();

  return pw.TableHelper.fromTextArray(
    headers: headers,
    data: [values],
    border: pw.TableBorder.all(width: 0.75, color: PdfColors.grey700),
    headerStyle:
        pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
    headerAlignment: pw.Alignment.centerLeft,
    cellStyle: _normal,
    cellAlignment: pw.Alignment.centerLeft,
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
  );
}

/// The bordered item table: No. | Description of Goods | Qty | Rate |
/// [Discount] | Amount. Splits across pages automatically for a long invoice,
/// repeating the column header on each new page.
pw.Widget _itemsTable(
    pw.Context context, ReceiptData data, bool showDiscountCol) {
  final amountCol = showDiscountCol ? 5 : 4;
  return pw.TableHelper.fromTextArray(
    context: context,
    headers: [
      'No.',
      'Description of Goods',
      'Qty',
      'Rate',
      if (showDiscountCol) 'Discount',
      'Amount',
    ],
    data: [
      for (var i = 0; i < data.lines.length; i++)
        [
          '${i + 1}',
          data.lines[i].name,
          _qtyWithUnit(data.lines[i].quantity, data.lines[i].unit),
          Fmt.money(data.lines[i].unitPrice),
          if (showDiscountCol)
            Fmt.money(data.lines[i].discountAmount, decimals: true),
          Fmt.money(data.lines[i].lineTotal, decimals: true),
        ],
    ],
    border: pw.TableBorder.all(width: 0.75, color: PdfColors.grey700),
    headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
    headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
    cellStyle: _normal,
    cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
    cellAlignments: {
      0: pw.Alignment.center,
      2: pw.Alignment.centerRight,
      3: pw.Alignment.centerRight,
      if (showDiscountCol) 4: pw.Alignment.centerRight,
      amountCol: pw.Alignment.centerRight,
    },
    columnWidths: {
      0: const pw.FixedColumnWidth(28),
      1: const pw.FlexColumnWidth(4.6),
      2: const pw.FlexColumnWidth(1.8),
      3: const pw.FlexColumnWidth(1.6),
      if (showDiscountCol) 4: const pw.FlexColumnWidth(1.6),
      amountCol: const pw.FlexColumnWidth(1.8),
    },
  );
}

pw.Widget _totalRow(String label, double value, {bool bold = false}) {
  final style = bold
      ? pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)
      : _normal;
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(label, style: style),
        pw.Text(Fmt.money(value, decimals: true), style: style),
      ],
    ),
  );
}

final pw.TextStyle _normal = const pw.TextStyle(fontSize: 9.5);
final pw.TextStyle _small = const pw.TextStyle(fontSize: 8.5);
final pw.TextStyle _tiny = pw.TextStyle(fontSize: 8, color: PdfColors.grey600);

String _num(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

String _qtyWithUnit(double v, String unit) =>
    unit.trim().isEmpty ? _num(v) : '${_num(v)} ${unit.trim()}';
