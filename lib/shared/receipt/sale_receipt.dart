import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../config/format.dart';
import '../../features/receipt_settings/data/model/receipt_settings_model.dart';
import '../../features/sale_invoice/data/model/sale_invoice_model.dart';

/// One printed line on a receipt.
class ReceiptLine {
  const ReceiptLine({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.lineTotal,
    this.discountAmount = 0,
  });

  final String name;
  final double quantity;
  final double unitPrice;
  final double lineTotal;
  final double discountAmount;
}

/// An extra totals row printed under Subtotal / Discount / Tax (e.g. "Paid",
/// "Balance").
class ReceiptTotal {
  const ReceiptTotal(this.label, this.value, {this.bold = false});

  final String label;
  final double value;
  final bool bold;
}

/// Everything the generic 80mm receipt needs — sale invoice, purchase, return
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

  /// Invoice notes. Printed in the header block only when it is non-empty and
  /// the "Invoice notes" toggle is on in Receipt Settings.
  final String notes;

  /// Extra `key: value` rows in the header block (e.g. `Against: SI-000042`).
  final List<(String, String)> extraInfo;

  /// Extra totals rows under Tax (e.g. Paid / Balance).
  final List<ReceiptTotal> extraTotals;

  int get itemCount => lines.length;
  double get totalQuantity => lines.fold(0, (a, l) => a + l.quantity);
}

/// Builds an 80mm thermal-receipt PDF for a saved [SaleInvoiceModel].
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

/// Builds an 80mm thermal-receipt PDF from a ready-made [ReceiptData].
///
/// The page is a single continuous roll (`PdfPageFormat.roll80`) so the printer
/// only feeds as much paper as the content needs.
Future<Uint8List> buildReceiptPdf(ReceiptData data) async {
  // Built-in Helvetica — no network fetch, works fully offline on the till.
  final doc = pw.Document();
  final theme = pw.ThemeData.withFont(
    base: pw.Font.helvetica(),
    bold: pw.Font.helveticaBold(),
  );

  final d = data.date;
  final dateStr = '${Fmt.date(d)}  '
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  // Shop header + which fields to print — configured on the Receipt Settings
  // screen, cached in ReceiptSettingsModel.current.
  final s = ReceiptSettingsModel.current;
  final showItemDiscount = s.showItemDiscount;

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.roll80.copyWith(
        marginLeft: 4 * PdfPageFormat.mm,
        marginRight: 4 * PdfPageFormat.mm,
        marginTop: 5 * PdfPageFormat.mm,
        marginBottom: 5 * PdfPageFormat.mm,
      ),
      theme: theme,
      build: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          if (s.showLogo && s.logo != null) ...[
            pw.Center(
              child: pw.Image(
                pw.MemoryImage(s.logo!),
                height: 40,
                fit: pw.BoxFit.contain,
              ),
            ),
            pw.SizedBox(height: 4),
          ],
          if (s.businessName.trim().isNotEmpty)
            pw.Center(
              child: pw.Text(
                s.businessName,
                style:
                    pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
            ),
          if (s.businessAddress.trim().isNotEmpty)
            pw.Center(
                child: pw.Text(s.businessAddress,
                    style: _small, textAlign: pw.TextAlign.center)),
          if (s.businessPhone.trim().isNotEmpty)
            pw.Center(child: pw.Text(s.businessPhone, style: _small)),
          pw.SizedBox(height: 4),
          pw.Center(
            child: pw.Text(data.docType,
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
          ),
          pw.SizedBox(height: 4),
          if (s.showInvoiceNo)
            _kv(data.docType.contains('RETURN') ? 'Return' : 'Invoice',
                data.invoiceNo.isEmpty ? '-' : data.invoiceNo),
          if (s.showDate) _kv('Date', dateStr),
          if (s.showParty)
            _kv(data.partyLabel,
                data.partyName.isEmpty ? '-' : data.partyName),
          if (s.showNotes && data.notes.trim().isNotEmpty)
            _kv('Notes', data.notes.trim()),
          for (final info in data.extraInfo) _kv(info.$1, info.$2),
          _dividerLine(),
          // Column header
          pw.Row(children: [
            pw.Expanded(flex: 5, child: pw.Text('Item', style: _smallBold)),
            pw.Expanded(
                flex: 2,
                child: pw.Text('Qty',
                    style: _smallBold, textAlign: pw.TextAlign.right)),
            pw.Expanded(
                flex: 3,
                child: pw.Text('Price',
                    style: _smallBold, textAlign: pw.TextAlign.right)),
            pw.Expanded(
                flex: 3,
                child: pw.Text('Total',
                    style: _smallBold, textAlign: pw.TextAlign.right)),
          ]),
          pw.SizedBox(height: 2),
          for (final it in data.lines) ...[
            pw.Text(it.name, style: _small),
            pw.Row(children: [
              pw.Expanded(flex: 5, child: pw.SizedBox()),
              pw.Expanded(
                  flex: 2,
                  child: pw.Text(_num(it.quantity),
                      style: _small, textAlign: pw.TextAlign.right)),
              pw.Expanded(
                  flex: 3,
                  child: pw.Text(Fmt.money(it.unitPrice),
                      style: _small, textAlign: pw.TextAlign.right)),
              pw.Expanded(
                  flex: 3,
                  child: pw.Text(Fmt.money(it.lineTotal, decimals: true),
                      style: _small, textAlign: pw.TextAlign.right)),
            ]),
            if (it.discountAmount > 0 && showItemDiscount)
              pw.Text('  discount -${Fmt.money(it.discountAmount, decimals: true)}',
                  style: _small),
          ],
          _dividerLine(),
          _total('Subtotal', data.subtotal),
          if (data.discountTotal > 0 && s.showDiscountTotal)
            _total('Discount', -data.discountTotal),
          if (data.taxTotal > 0 && s.showTaxTotal)
            _total('Tax', data.taxTotal),
          pw.SizedBox(height: 2),
          _total(data.grandTotalLabel, data.grandTotal, bold: true),
          if (s.showPaidBalance)
            for (final t in data.extraTotals)
              _total(t.label, t.value, bold: t.bold),
          if (s.showFooter && s.footerText.trim().isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Center(
                child: pw.Text(s.footerText.trim(),
                    style: _small, textAlign: pw.TextAlign.center)),
          ],
          if (s.showItemCount) ...[
            pw.SizedBox(height: 4),
            pw.Center(
                child: pw.Text('${data.itemCount} item(s)  -  '
                    '${_num(data.totalQuantity)} unit(s)', style: _small)),
          ],
        ],
      ),
    ),
  );

  return doc.save();
}

final pw.TextStyle _small = const pw.TextStyle(fontSize: 8);
final pw.TextStyle _smallBold =
    pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold);

pw.Widget _kv(String k, String v) => pw.Row(children: [
      pw.Text('$k: ', style: _small),
      pw.Expanded(child: pw.Text(v, style: _small)),
    ]);

pw.Widget _total(String label, double value, {bool bold = false}) {
  final style = bold
      ? pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)
      : _small;
  return pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(label, style: style),
      pw.Text(Fmt.money(value, decimals: true), style: style),
    ],
  );
}

pw.Widget _dividerLine() => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Divider(height: 0.5, thickness: 0.5),
    );

String _num(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
