import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos/shared/app_icon.dart';

import '../../../../config/format.dart';
import '../../../../shared/searchable_dropdown.dart';
import '../../../bank/data/model/bank_head_model.dart';
import '../../../sale_invoice/data/model/sale_invoice_refs.dart';
import '../../data/model/customer_payment_model.dart';

/// Add / edit form for a customer payment. Pops a [CustomerPaymentModel] on save.
class CustomerPaymentFormDialog extends StatefulWidget {
  const CustomerPaymentFormDialog({
    super.key,
    this.initial,
    required this.customers,
    required this.banks,
    this.suggestNo,
  });

  final CustomerPaymentModel? initial;
  final List<CustomerRef> customers;
  final List<BankHeadModel> banks;

  /// Suggested payment number for a new payment.
  final String Function()? suggestNo;

  @override
  State<CustomerPaymentFormDialog> createState() =>
      _CustomerPaymentFormDialogState();
}

class _CustomerPaymentFormDialogState
    extends State<CustomerPaymentFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late DateTime _date = widget.initial?.date ?? DateTime.now();
  CustomerRef? _customer;
  BankHeadModel? _bank;

  late final _paymentNo = TextEditingController(
    text: widget.initial?.paymentNo ?? widget.suggestNo?.call() ?? '',
  );
  late final _amount = TextEditingController(
    text: widget.initial == null
        ? ''
        : widget.initial!.amount.toStringAsFixed(2),
  );
  late final _reference =
      TextEditingController(text: widget.initial?.reference ?? '');
  late final _narration =
      TextEditingController(text: widget.initial?.narration ?? '');

  bool get _isEdit => widget.initial?.id != null;

  @override
  void initState() {
    super.initState();
    final customerId = widget.initial?.customerId;
    if (customerId != null) {
      for (final c in widget.customers) {
        if (c.id == customerId) {
          _customer = c;
          break;
        }
      }
    }
    final bankId = widget.initial?.bankHeadId;
    if (bankId != null) {
      for (final b in widget.banks) {
        if (b.id == bankId) {
          _bank = b;
          break;
        }
      }
    }
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _paymentNo.dispose();
    _amount.dispose();
    _reference.dispose();
    _narration.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  double get _due => _customer?.openingBalance ?? 0;
  double get _amt => double.tryParse(_amount.text.trim()) ?? 0;
  double get _remainingDue => _due - _amt;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final model = (widget.initial ??
            CustomerPaymentModel(date: _date, customerId: _customer!.id))
        .copyWith(
      paymentNo: _paymentNo.text.trim(),
      date: _date,
      customerId: _customer!.id,
      customerName: _customer!.name,
      amount: _amt,
      bankHeadId: _bank?.id,
      clearBankHeadId: _bank == null,
      reference: _reference.text.trim(),
      narration: _narration.text.trim(),
    );
    Navigator.pop(context, model);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Payment' : 'Receive Payment'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _paymentNo,
                        decoration:
                            const InputDecoration(hintText: 'Payment No'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: _pickDate,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            hintText: 'Date',
                            prefixIcon: AppIcon(AppIcons.event, size: 18),
                          ),
                          child: Text(Fmt.date(_date)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SearchableDropdown<CustomerRef>(
                  items: widget.customers,
                  value: _customer,
                  itemLabel: (c) => c.name,
                  hintText: 'Customer *',
                  enabled: !_isEdit,
                  onChanged: (c) => setState(() => _customer = c),
                  validator: (c) => c == null ? 'Pick a customer' : null,
                ),
                if (_customer != null) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Currently due: ${Fmt.money(_due)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _due > 0
                            ? scheme.error
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amount,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  decoration: const InputDecoration(
                    hintText: 'Amount received *',
                    prefixText: 'Rs ',
                  ),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').trim());
                    if (n == null || n <= 0) return 'Enter an amount';
                    return null;
                  },
                ),
                if (_customer != null && _amt > 0) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Remaining due after this: ${Fmt.money(_remainingDue)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _remainingDue > 0
                            ? scheme.error
                            : const Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SearchableDropdown<BankHeadModel>(
                  items: widget.banks,
                  value: _bank,
                  itemLabel: (b) => b.title,
                  hintText: 'Deposit to',
                  includeNull: true,
                  nullLabel: 'Cash',
                  onChanged: (b) => setState(() => _bank = b),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reference,
                  decoration: const InputDecoration(
                      hintText: 'Reference (cheque / receipt no)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _narration,
                  maxLines: 2,
                  decoration: const InputDecoration(hintText: 'Narration'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isEdit ? 'Save' : 'Receive'),
        ),
      ],
    );
  }
}
