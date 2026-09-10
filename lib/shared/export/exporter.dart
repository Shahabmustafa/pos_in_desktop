import 'dart:convert';
import 'dart:io';

import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pos/shared/app_icon.dart';

import 'export_doc.dart';

/// The export targets offered in the Export menu.
enum ExportFormat {
  csv('CSV (.csv)', AppIcons.description_outlined),
  excel('Excel (.xlsx)', AppIcons.grid_on),
  pdf('PDF (.pdf)', AppIcons.receipt_long_outlined),
  printer('Print', AppIcons.print_outlined),
  clipboard('Copy to clipboard', AppIcons.copy);

  const ExportFormat(this.label, this.icon);

  final String label;
  final String icon;
}

/// Turns an [ExportDoc] into a file, a print job, or clipboard text. Every path
/// reports success / failure through a SnackBar and never throws.
class Exporter {
  const Exporter._();

  static Future<void> run(
    BuildContext context,
    ExportDoc doc,
    ExportFormat format,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      switch (format) {
        case ExportFormat.csv:
          final saved = await _save(doc.fileBase, 'csv', _csvBytes(doc));
          _toast(messenger, saved == null ? null : 'Saved to $saved');
        case ExportFormat.excel:
          final saved = await _save(doc.fileBase, 'xlsx', _xlsxBytes(doc));
          _toast(messenger, saved == null ? null : 'Saved to $saved');
        case ExportFormat.pdf:
          final saved = await _save(doc.fileBase, 'pdf', await _pdfBytes(doc));
          _toast(messenger, saved == null ? null : 'Saved to $saved');
        case ExportFormat.printer:
          await Printing.layoutPdf(
            name: doc.fileBase,
            onLayout: (_) async => _pdfBytes(doc),
            format: PdfPageFormat.a4.landscape,
          );
        case ExportFormat.clipboard:
          await Clipboard.setData(ClipboardData(text: _delimited(doc, '\t')));
          _toast(messenger, 'Copied — paste into Excel or Google Sheets');
      }
    } catch (e) {
      _toast(messenger, 'Export failed: $e', error: true);
    }
  }

  // ── file save (desktop / mobile) ──────────────────────────────────
  /// Returns the saved path, or `null` if the user cancelled.
  static Future<String?> _save(String base, String ext, Uint8List bytes) async {
    final path = await FilePicker.saveFile(
      dialogTitle: 'Export',
      fileName: '$base.$ext',
      type: FileType.custom,
      allowedExtensions: [ext],
      bytes: bytes, // mobile writes directly from this
    );
    if (path == null) return null;
    // On desktop `saveFile` only returns the chosen path — write it here.
    final f = File(path);
    if (!await f.exists() || await f.length() != bytes.length) {
      await f.writeAsBytes(bytes, flush: true);
    }
    return path;
  }

  // ── CSV / TSV ─────────────────────────────────────────────────────
  static Uint8List _csvBytes(ExportDoc doc) => Uint8List.fromList(
        [0xEF, 0xBB, 0xBF, ...utf8.encode(_delimited(doc, ','))],
      );

  static String _delimited(ExportDoc doc, String sep) {
    final b = StringBuffer();
    for (var i = 0; i < doc.tables.length; i++) {
      final t = doc.tables[i];
      if (i > 0) b.writeln();
      if (t.heading != null) b.writeln(_field(t.heading!, sep));
      b.writeln(t.columns.map((c) => _field(c, sep)).join(sep));
      for (final row in t.rows) {
        b.writeln(row.map((c) => _field(c, sep)).join(sep));
      }
    }
    return b.toString();
  }

  static String _field(String v, String sep) {
    if (sep == '\t') {
      return v.replaceAll('\t', ' ').replaceAll(RegExp(r'[\r\n]+'), ' ');
    }
    final needsQuote = v.contains(sep) ||
        v.contains('"') ||
        v.contains('\n') ||
        v.contains('\r');
    return needsQuote ? '"${v.replaceAll('"', '""')}"' : v;
  }

  // ── Excel ─────────────────────────────────────────────────────────
  static Uint8List _xlsxBytes(ExportDoc doc) {
    final book = xl.Excel.createExcel();
    final name = _sheetName(doc.title);
    final def = book.getDefaultSheet();
    if (def != null && def != name) book.rename(def, name);
    final sheet = book[name];

    for (var i = 0; i < doc.tables.length; i++) {
      final t = doc.tables[i];
      if (i > 0) sheet.appendRow(const <xl.CellValue?>[]);
      if (t.heading != null) {
        sheet.appendRow(<xl.CellValue?>[xl.TextCellValue(t.heading!)]);
      }
      sheet.appendRow([for (final c in t.columns) xl.TextCellValue(c)]);
      for (final row in t.rows) {
        sheet.appendRow([for (final c in row) _xlCell(c)]);
      }
    }
    return Uint8List.fromList(book.encode() ?? const []);
  }

  static xl.CellValue _xlCell(String s) {
    final n = _asNum(s);
    return n != null ? xl.DoubleCellValue(n) : xl.TextCellValue(s);
  }

  static String _sheetName(String title) {
    var s = title.replaceAll(RegExp(r'[\[\]\*/\\?:]'), ' ').trim();
    if (s.length > 31) s = s.substring(0, 31);
    return s.isEmpty ? 'Export' : s;
  }

  // ── PDF ───────────────────────────────────────────────────────────
  static Future<Uint8List> _pdfBytes(ExportDoc doc) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => [
          pw.Text(doc.title,
              style:
                  pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          if (doc.subtitle != null) ...[
            pw.SizedBox(height: 2),
            pw.Text(doc.subtitle!,
                style:
                    const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          ],
          pw.SizedBox(height: 14),
          for (final t in doc.tables) ...[
            if (t.heading != null) ...[
              pw.SizedBox(height: 8),
              pw.Text(t.heading!,
                  style: pw.TextStyle(
                      fontSize: 12, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
            ],
            pw.TableHelper.fromTextArray(
              headers: t.columns,
              data: t.rows,
              headerStyle:
                  pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration:
                  const pw.BoxDecoration(color: PdfColors.grey200),
              cellHeight: 18,
              border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            ),
            pw.SizedBox(height: 12),
          ],
          pw.Text(
            'Exported ${DateTime.now().toString().split('.').first}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
          ),
        ],
      ),
    );
    return pdf.save();
  }

  // ── shared ────────────────────────────────────────────────────────
  static double? _asNum(String s) {
    final t = s
        .trim()
        .replaceAll('Rs', '')
        .replaceAll(',', '')
        .replaceAll('%', '')
        .replaceAll('+', '')
        .trim();
    if (t.isEmpty || t == '-' || t == '—') return null;
    return double.tryParse(t);
  }

  static void _toast(ScaffoldMessengerState m, String? msg,
      {bool error = false}) {
    if (msg == null) return; // cancelled — say nothing
    m.showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? const Color(0xFFC62828) : null,
    ));
  }
}
