import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Builds an 80mm thermal-printer label for a single product barcode:
/// the product name, an optional price line, then a scannable Code 128 barcode
/// with its digits printed underneath.
Future<Uint8List> buildBarcodeLabelPdf({
  required String barcode,
  required String productName,
  String? priceLabel,
}) async {
  final data = barcode.trim();
  final doc = pw.Document();
  final theme = pw.ThemeData.withFont(
    base: pw.Font.helvetica(),
    bold: pw.Font.helveticaBold(),
  );

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.roll80.copyWith(
        marginLeft: 3 * PdfPageFormat.mm,
        marginRight: 3 * PdfPageFormat.mm,
        marginTop: 4 * PdfPageFormat.mm,
        marginBottom: 4 * PdfPageFormat.mm,
      ),
      theme: theme,
      build: (context) => pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            productName.isEmpty ? '-' : productName,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
            maxLines: 2,
          ),
          if (priceLabel != null && priceLabel.isNotEmpty) ...[
            pw.SizedBox(height: 2),
            pw.Text(priceLabel, style: const pw.TextStyle(fontSize: 9)),
          ],
          pw.SizedBox(height: 4),
          pw.BarcodeWidget(
            data: data,
            barcode: pw.Barcode.code128(),
            drawText: true,
            width: 70 * PdfPageFormat.mm,
            height: 18 * PdfPageFormat.mm,
            textStyle: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    ),
  );

  return doc.save();
}
