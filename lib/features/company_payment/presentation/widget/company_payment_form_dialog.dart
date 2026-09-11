import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos/shared/app_icon.dart';

import '../../../../config/format.dart';
import '../../../../shared/searchable_dropdown.dart';
import '../../../bank/data/model/bank_head_model.dart';
import '../../data/model/company_payable_ref.dart';
import '../../data/model/company_payment_model.dart';

/// Add / edit form for a company payment. Pops a [CompanyPaymentModel] on save.
class CompanyPaymentFormDialog extends StatefulWidget {
  const CompanyPaymentFormDialog({
    super.key,
    this.initial,
    required this.companies,
    required this.banks,
    this.suggestNo,
  });

  final CompanyPaymentModel? initial;
  final List<CompanyPayableRef> companies;
  final List<BankHeadModel> banks;

  /// Suggested payment number for a new payment.
  final String Function()? suggestNo;

  @override
  State<CompanyPaymentFormDialog> createState() =>
      _CompanyPaymentFormDialogState();
}

class _CompanyPaymentFormDialogState extends State<CompanyPaymentFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late DateTime _date = widget.initial?.date ?? DateTime.now();
  CompanyPayableRef? _company;
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
    final companyId = widget.initial?.companyId;
    if (companyId != null) {
      for (final c in widget.companies) {
        if (c.id == companyId) {
          _company = c;
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

  double get _payable => _company?.payable ?? 0;
  double get _amt => double.tryParse(_amount.text.trim()) ?? 0;
  double get _remainingPayable => _payable - _amt;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final model = (widget.initial ??
            CompanyPaymentModel(date: _date, companyId: _company!.id))
        .copyWith(
      paymentNo: _paymentNo.text.trim(),
      date: _date,
      companyId: _company!.id,
      companyName: _company!.name,
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
      title: Text(_isEdit ? 'Edit Payment' : 'Pay Company'),
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
                SearchableDropdown<CompanyPayableRef>(
                  items: widget.companies,
                  value: _company,
                  itemLabel: (c) => c.name,
                  hintText: 'Company *',
                  enabled: !_isEdit,
                  onChanged: (c) => setState(() => _company = c),
                  validator: (c) => c == null ? 'Pick a company' : null,
                ),
                if (_company != null) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Currently payable: ${Fmt.money(_payable)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _payable > 0
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
                    hintText: 'Amount paid *',
                    prefixText: 'Rs ',
                  ),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').trim());
                    if (n == null || n <= 0) return 'Enter an amount';
                    return null;
                  },
                ),
                if (_company != null && _amt > 0) ...[
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Remaining payable after this: ${Fmt.money(_remainingPayable)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _remainingPayable > 0
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
                  hintText: 'Pay from',
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
          child: Text(_isEdit ? 'Save' : 'Pay'),
        ),
      ],
    );
  }
}
