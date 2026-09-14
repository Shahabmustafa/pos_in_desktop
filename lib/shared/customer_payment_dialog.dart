import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/format.dart';
import 'app_icon.dart';

/// What [showCustomerPaymentDialog] returns once the user confirms.
class CustomerPaymentResult {
  const CustomerPaymentResult(this.payAmount);

  /// Amount the customer pays / is paid back now. The rest of the bill lands
  /// on the customer's running balance.
  final double payAmount;
}

/// Confirmation shown when a sale invoice / sale return (customer) or a
/// purchase invoice (company) is saved for a real party. Lets the operator
/// enter how much is paid now; the remainder is added to the party's running
/// balance.
///
/// Returns `null` when the operator cancels.
Future<CustomerPaymentResult?> showCustomerPaymentDialog(
  BuildContext context, {
  required String customerName,
  required double previousBalance,
  required double totalAmount,
  required String totalLabel,
  required String actionLabel,
  String partyLabel = 'Customer',
  String icon = AppIcons.person_outline,
  Color accent = const Color(0xFF2E7D32),
}) {
  return showDialog<CustomerPaymentResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _CustomerPaymentDialog(
      customerName: customerName,
      previousBalance: previousBalance,
      totalAmount: totalAmount,
      totalLabel: totalLabel,
      actionLabel: actionLabel,
      partyLabel: partyLabel,
      icon: icon,
      accent: accent,
    ),
  );
}

class _CustomerPaymentDialog extends StatefulWidget {
  const _CustomerPaymentDialog({
    required this.customerName,
    required this.previousBalance,
    required this.totalAmount,
    required this.totalLabel,
    required this.actionLabel,
    required this.partyLabel,
    required this.icon,
    required this.accent,
  });

  final String customerName;
  final double previousBalance;
  final double totalAmount;
  final String totalLabel;
  final String actionLabel;

  /// e.g. 'Customer' (Sale Invoice / Sale Return) or 'Company' (Purchase
  /// Invoice).
  final String partyLabel;
  final String icon;
  final Color accent;

  @override
  State<_CustomerPaymentDialog> createState() => _CustomerPaymentDialogState();
}

class _CustomerPaymentDialogState extends State<_CustomerPaymentDialog> {
  late final TextEditingController _payCtrl =
      TextEditingController(text: _fmt(widget.totalAmount));

  @override
  void initState() {
    super.initState();
    _payCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _payCtrl.dispose();
    super.dispose();
  }

  double get _pay => double.tryParse(_payCtrl.text.trim()) ?? 0;
  double get _remaining => widget.totalAmount - _pay;
  double get _newBalance => widget.previousBalance + _remaining;

  void _confirm() =>
      Navigator.pop(context, CustomerPaymentResult(_pay));

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Row(children: [
        AppIcon(widget.icon, size: 20, color: widget.accent),
        const SizedBox(width: 8),
        const Text('Confirm payment'),
      ]),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _row(scheme, widget.partyLabel, widget.customerName, strong: true),
            const SizedBox(height: 6),
            _row(scheme, 'Previous amount', Fmt.money(widget.previousBalance)),
            _row(scheme, widget.totalLabel, Fmt.money(widget.totalAmount)),
            const SizedBox(height: 10),
            TextField(
              controller: _payCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
              ],
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Pay amount',
                prefixText: 'Rs ',
              ),
              onSubmitted: (_) => _confirm(),
            ),
            const SizedBox(height: 10),
            _row(scheme, 'Remaining amount', Fmt.money(_remaining),
                color: _remaining > 0
                    ? scheme.error
                    : _remaining < 0
                        ? const Color(0xFF2E7D32)
                        : null),
            const Divider(height: 18),
            _row(scheme, 'Total ${widget.partyLabel.toLowerCase()} amount',
                Fmt.money(_newBalance), strong: true, color: widget.accent),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _confirm,
          style: FilledButton.styleFrom(backgroundColor: widget.accent),
          child: Text(widget.actionLabel),
        ),
      ],
    );
  }

  Widget _row(ColorScheme scheme, String label, String value,
      {bool strong = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
          Text(value,
              style: TextStyle(
                  fontSize: strong ? 15 : 13,
                  fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
                  color: color)),
        ],
      ),
    );
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}
