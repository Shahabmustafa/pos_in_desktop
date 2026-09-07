import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/sale_invoice/data/model/sale_invoice_model.dart';
import 'sale_receipt.dart';

/// Sends receipts to a system-installed (USB / network) thermal printer.
///
/// The first receipt after install shows the OS printer picker; the chosen
/// printer is remembered so every later sale prints silently.
class ReceiptPrinter {
  ReceiptPrinter._();

  static final ReceiptPrinter instance = ReceiptPrinter._();

  static const _kPrinterUrl = 'receipt_printer_url';
  static const _kPrinterName = 'receipt_printer_name';

  static final PdfPageFormat _roll = PdfPageFormat.roll80;

  /// Name of the printer receipts currently go to, if one has been chosen.
  Future<String?> selectedPrinterName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kPrinterName);
  }

  /// Lets the user pick / change the receipt printer.
  Future<void> choosePrinter(BuildContext context) async {
    final picked = await Printing.pickPrinter(context: context);
    if (picked == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrinterUrl, picked.url);
    await prefs.setString(_kPrinterName, picked.name);
  }

  /// Prints the receipt for a saved sale [invoice].
  Future<void> printSaleInvoice(
    BuildContext context,
    SaleInvoiceModel invoice, {
    void Function(String message)? onError,
  }) {
    return printReceipt(context, buildSaleReceiptPdf(invoice), onError: onError);
  }

  /// Prints any receipt from its already-built (or building) PDF bytes. Silent
  /// once a printer is remembered; otherwise it prompts once (picker), then
  /// remembers the choice. Any failure is reported through [onError] rather than
  /// thrown, so a print problem never blocks the transaction.
  Future<void> printReceipt(
    BuildContext context,
    Future<Uint8List> pdfBytes, {
    void Function(String message)? onError,
  }) async {
    try {
      final bytes = await pdfBytes;
      final prefs = await SharedPreferences.getInstance();
      var url = prefs.getString(_kPrinterUrl);

      if (url == null || url.isEmpty) {
        if (!context.mounted) return;
        final picked = await Printing.pickPrinter(context: context);
        if (picked == null) {
          // No printer chosen — fall back to the OS print dialog this once.
          await Printing.layoutPdf(
              onLayout: (_) async => bytes, format: _roll);
          return;
        }
        url = picked.url;
        await prefs.setString(_kPrinterUrl, url);
        await prefs.setString(_kPrinterName, picked.name);
      }

      try {
        await Printing.directPrintPdf(
          printer: Printer(url: url),
          onLayout: (_) async => bytes,
          format: _roll,
          usePrinterSettings: true,
        );
      } catch (_) {
        // Stored printer gone / offline — reset and show the dialog.
        await prefs.remove(_kPrinterUrl);
        await prefs.remove(_kPrinterName);
        await Printing.layoutPdf(onLayout: (_) async => bytes, format: _roll);
      }
    } catch (e) {
      onError?.call('Could not print the receipt: $e');
    }
  }
}
