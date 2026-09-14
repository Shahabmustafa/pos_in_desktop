import 'package:flutter/material.dart';

import '../../../../config/format.dart';
import '../../data/model/receipt_settings_model.dart';

/// An on-screen mock of the A4 tabular invoice, drawn from sample data so the
/// user sees the effect of every [ReceiptSettingsModel] change as they make it.
///
/// It mirrors the layout of `buildReceiptPdf` in
/// `lib/shared/receipt/sale_receipt.dart` — keep the two in step.
class ReceiptPreview extends StatelessWidget {
  const ReceiptPreview({super.key, required this.settings});

  final ReceiptSettingsModel settings;

  // Sample sale invoice used only for the preview.
  static const _sampleLines = <(String, double, double, double)>[
    ('Coca-Cola 1.5L', 3, 120, 36), // name, qty, price, lineDiscount
    ('Lays Masala 62g', 2, 70, 0),
  ];
  static const double _sampleSubtotal = 3 * 120 + 2 * 70; // 500
  static const double _sampleDiscount = 36;
  static const double _sampleTax = 23.2;
  static const double _sampleGrand = _sampleSubtotal - _sampleDiscount + _sampleTax;
  static const double _samplePaid = 450;

  static const _border = BorderSide(color: Color(0xFF9E9E9E), width: 0.6);

  @override
  Widget build(BuildContext context) {
    final s = settings;
    final showDiscountCol = s.showItemDiscount;

    return Container(
      width: 340,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: DefaultTextStyle(
        style: const TextStyle(fontSize: 10.5, color: Color(0xFF111111)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (s.showLogo && s.logo != null) ...[
              Center(
                child: Image.memory(
                  s.logo!,
                  height: 40,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 4),
            ],
            if (s.businessName.trim().isNotEmpty)
              Center(
                child: Text(
                  s.businessName,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            if (s.businessAddress.trim().isNotEmpty)
              Center(child: Text(s.businessAddress, textAlign: TextAlign.center)),
            if (s.businessPhone.trim().isNotEmpty)
              Center(child: Text(s.businessPhone)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(vertical: 5),
              decoration: const BoxDecoration(
                border: Border(top: _border, bottom: _border),
              ),
              child: const Text('SALE INVOICE',
                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            ),
            const SizedBox(height: 8),
            _infoGrid(s),
            if (s.showNotes) ...[
              const SizedBox(height: 4),
              const Text('Notes: Deliver before 5pm'),
            ],
            const SizedBox(height: 10),
            _itemsTable(showDiscountCol),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 220,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _total('Subtotal', _sampleSubtotal),
                    if (s.showDiscountTotal) _total('Discount', -_sampleDiscount),
                    if (s.showTaxTotal) _total('Tax', _sampleTax),
                    const Divider(height: 10, thickness: 0.6),
                    _total('GRAND TOTAL', _sampleGrand, bold: true),
                    if (s.showPaidBalance) ...[
                      _total('Paid', _samplePaid),
                      _total('Balance', _sampleGrand - _samplePaid, bold: true),
                    ],
                  ],
                ),
              ),
            ),
            if (s.showFooter && s.footerText.trim().isNotEmpty) ...[
              const SizedBox(height: 14),
              Center(child: Text(s.footerText, textAlign: TextAlign.center)),
            ],
            if (s.showItemCount) ...[
              const SizedBox(height: 6),
              const Text('2 item(s)  -  5 unit(s)', style: TextStyle(fontSize: 9)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoGrid(ReceiptSettingsModel s) {
    final headers = <String>[];
    final values = <String>[];
    if (s.showParty) {
      headers.add('Customer');
      values.add('Ali Traders');
    }
    if (s.showInvoiceNo) {
      headers.add('Invoice No.');
      values.add('SI-000042');
    }
    if (s.showDate) {
      headers.add('Dated');
      values.add(Fmt.date(DateTime(2026, 9, 9)));
    }
    if (headers.isEmpty) return const SizedBox();

    return Table(
      border: TableBorder.all(color: const Color(0xFF9E9E9E), width: 0.6),
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFEEEEEE)),
          children: [
            for (final h in headers) _cell(h, bold: true),
          ],
        ),
        TableRow(children: [for (final v in values) _cell(v)]),
      ],
    );
  }

  Widget _itemsTable(bool showDiscountCol) {
    return Table(
      border: TableBorder.all(color: const Color(0xFF9E9E9E), width: 0.6),
      columnWidths: {
        0: const FixedColumnWidth(20),
        1: const FlexColumnWidth(5),
        2: const FlexColumnWidth(1.4),
        3: const FlexColumnWidth(1.6),
        if (showDiscountCol) 4: const FlexColumnWidth(1.6),
        (showDiscountCol ? 5 : 4): const FlexColumnWidth(1.8),
      },
      children: [
        TableRow(
          decoration: const BoxDecoration(color: Color(0xFFEEEEEE)),
          children: [
            _cell('No.', bold: true, align: TextAlign.center),
            _cell('Description', bold: true),
            _cell('Qty', bold: true, align: TextAlign.right),
            _cell('Rate', bold: true, align: TextAlign.right),
            if (showDiscountCol) _cell('Disc', bold: true, align: TextAlign.right),
            _cell('Amount', bold: true, align: TextAlign.right),
          ],
        ),
        for (var i = 0; i < _sampleLines.length; i++)
          TableRow(children: [
            _cell('${i + 1}', align: TextAlign.center),
            _cell(_sampleLines[i].$1),
            _cell(_num(_sampleLines[i].$2), align: TextAlign.right),
            _cell(Fmt.money(_sampleLines[i].$3), align: TextAlign.right),
            if (showDiscountCol)
              _cell(Fmt.money(_sampleLines[i].$4, decimals: true),
                  align: TextAlign.right),
            _cell(
                Fmt.money(
                    _sampleLines[i].$2 * _sampleLines[i].$3 - _sampleLines[i].$4,
                    decimals: true),
                align: TextAlign.right),
          ]),
      ],
    );
  }

  static Widget _cell(String text, {bool bold = false, TextAlign? align}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Text(text,
            textAlign: align,
            style: TextStyle(
                fontSize: 9.5,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
      );

  static Widget _total(String label, double value, {bool bold = false}) {
    final style = TextStyle(
      fontSize: bold ? 11.5 : 10.5,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      color: const Color(0xFF111111),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
              child: Text(label, style: style, overflow: TextOverflow.ellipsis)),
          Text(Fmt.money(value, decimals: true), style: style),
        ],
      ),
    );
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}
