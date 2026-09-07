import 'package:flutter/material.dart';

import '../../../../config/format.dart';
import '../../data/model/receipt_settings_model.dart';

/// An on-screen mock of the 80mm thermal receipt, drawn from sample data so the
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

  @override
  Widget build(BuildContext context) {
    final s = settings;

    return Container(
      width: 260,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 10.5,
          height: 1.35,
          color: Color(0xFF111111),
        ),
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
                    fontFamily: 'monospace',
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111111),
                  ),
                ),
              ),
            if (s.businessAddress.trim().isNotEmpty)
              Center(child: Text(s.businessAddress, textAlign: TextAlign.center)),
            if (s.businessPhone.trim().isNotEmpty)
              Center(child: Text(s.businessPhone)),
            const SizedBox(height: 6),
            const Center(
              child: Text('SALE INVOICE',
                  style: TextStyle(
                      fontFamily: 'monospace', fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 6),
            if (s.showInvoiceNo) _kv('Invoice', 'SI-000042'),
            if (s.showDate) _kv('Date', '${Fmt.date(DateTime(2026, 9, 9))}  14:05'),
            if (s.showParty) _kv('Customer', 'Ali Traders'),
            if (s.showNotes) _kv('Notes', 'Deliver before 5pm'),
            _dashes(),
            Row(
              children: const [
                Expanded(flex: 5, child: _B('Item')),
                Expanded(
                    flex: 2,
                    child: _B('Qty', align: TextAlign.right)),
                Expanded(
                    flex: 3,
                    child: _B('Price', align: TextAlign.right)),
                Expanded(
                    flex: 3,
                    child: _B('Total', align: TextAlign.right)),
              ],
            ),
            const SizedBox(height: 2),
            for (final line in _sampleLines) ...[
              Text(line.$1),
              Row(
                children: [
                  const Expanded(flex: 5, child: SizedBox()),
                  Expanded(
                      flex: 2,
                      child: Text(_num(line.$2),
                          textAlign: TextAlign.right)),
                  Expanded(
                      flex: 3,
                      child: Text(Fmt.money(line.$3),
                          textAlign: TextAlign.right)),
                  Expanded(
                      flex: 3,
                      child: Text(
                          Fmt.money(line.$2 * line.$3 - line.$4,
                              decimals: true),
                          textAlign: TextAlign.right)),
                ],
              ),
              if (line.$4 > 0 && s.showItemDiscount)
                Text('  discount -${Fmt.money(line.$4, decimals: true)}'),
            ],
            _dashes(),
            _total('Subtotal', _sampleSubtotal),
            if (s.showDiscountTotal) _total('Discount', -_sampleDiscount),
            if (s.showTaxTotal) _total('Tax', _sampleTax),
            const SizedBox(height: 2),
            _total('GRAND TOTAL', _sampleGrand, bold: true),
            if (s.showPaidBalance) ...[
              _total('Paid', _samplePaid),
              _total('Balance', _sampleGrand - _samplePaid, bold: true),
            ],
            const SizedBox(height: 8),
            if (s.showFooter && s.footerText.trim().isNotEmpty)
              Center(child: Text(s.footerText, textAlign: TextAlign.center)),
            if (s.showItemCount) ...[
              const SizedBox(height: 4),
              const Center(child: Text('2 item(s)  -  5 unit(s)')),
            ],
          ],
        ),
      ),
    );
  }

  static Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.only(bottom: 1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$k: '),
            Expanded(child: Text(v)),
          ],
        ),
      );

  static Widget _total(String label, double value, {bool bold = false}) {
    final style = TextStyle(
      fontFamily: 'monospace',
      fontSize: bold ? 11.5 : 10.5,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      color: const Color(0xFF111111),
    );
    return Row(
      children: [
        Expanded(
          child: Text(label, style: style, overflow: TextOverflow.ellipsis),
        ),
        Text(Fmt.money(value, decimals: true), style: style),
      ],
    );
  }

  static Widget _dashes() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 3),
        child: Text('--------------------------------',
            maxLines: 1, overflow: TextOverflow.clip),
      );

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}

class _B extends StatelessWidget {
  const _B(this.text, {this.align});

  final String text;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: align,
        style: const TextStyle(
          fontFamily: 'monospace',
          fontSize: 10.5,
          fontWeight: FontWeight.bold,
          color: Color(0xFF111111),
        ),
      );
}
