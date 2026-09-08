import 'package:flutter/material.dart';
import 'package:pos/shared/app_icon.dart';
import 'package:flutter/services.dart';

import '../../../../config/format.dart';
import '../../data/model/voucher_model.dart';

/// Add / edit form for a voucher. Pops a [VoucherModel] on save.
class VoucherFormDialog extends StatefulWidget {
  const VoucherFormDialog({super.key, this.initial, this.suggestNo});

  final VoucherModel? initial;

  /// Given a type, returns a suggested voucher number (for new vouchers).
  final String Function(VoucherType type)? suggestNo;

  @override
  State<VoucherFormDialog> createState() => _VoucherFormDialogState();
}

class _VoucherFormDialogState extends State<VoucherFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late VoucherType _type = widget.initial?.type ?? VoucherType.payment;
  late DateTime _date = widget.initial?.date ?? DateTime.now();
  late VoucherMode _mode = widget.initial?.mode ?? VoucherMode.cash;
  late final _voucherNo = TextEditingController(
    text: widget.initial?.voucherNo ??
        widget.suggestNo?.call(_type) ??
        '',
  );
  late final _party = TextEditingController(text: widget.initial?.party ?? '');
  late final _amount = TextEditingController(
      text: widget.initial == null
          ? ''
          : widget.initial!.amount.toStringAsFixed(2));
  late final _reference =
      TextEditingController(text: widget.initial?.reference ?? '');
  late final _narration =
      TextEditingController(text: widget.initial?.narration ?? '');

  bool get _isEdit => widget.initial?.id != null;

  @override
  void dispose() {
    _voucherNo.dispose();
    _party.dispose();
    _amount.dispose();
    _reference.dispose();
    _narration.dispose();
    super.dispose();
  }

  void _onTypeChanged(VoucherType t) {
    setState(() {
      _type = t;
      // Refresh the suggested number for new vouchers only.
      if (!_isEdit && widget.suggestNo != null) {
        _voucherNo.text = widget.suggestNo!(t);
      }
    });
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final model =
        (widget.initial ?? VoucherModel(date: _date)).copyWith(
      voucherNo: _voucherNo.text.trim(),
      date: _date,
      type: _type,
      party: _party.text.trim(),
      amount: double.tryParse(_amount.text.trim()) ?? 0,
      mode: _mode,
      reference: _reference.text.trim(),
      narration: _narration.text.trim(),
    );
    Navigator.pop(context, model);
  }

  @override
  Widget build(BuildContext context) {
    final partyHint = switch (_type) {
      VoucherType.payment => 'Paid to',
      VoucherType.receipt => 'Received from',
      VoucherType.journal => 'Account / party',
    };

    return AlertDialog(
      title: Text(_isEdit ? 'Edit Voucher' : 'Add Voucher'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<VoucherType>(
                  segments: const [
                    ButtonSegment(
                        value: VoucherType.payment, label: Text('Payment')),
                    ButtonSegment(
                        value: VoucherType.receipt, label: Text('Receipt')),
                    ButtonSegment(
                        value: VoucherType.journal, label: Text('Journal')),
                  ],
                  selected: {_type},
                  onSelectionChanged: (s) => _onTypeChanged(s.first),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _voucherNo,
                        decoration:
                            const InputDecoration(hintText: 'Voucher No'),
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
                TextFormField(
                  controller: _party,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(hintText: '$partyHint *'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? '$partyHint is required'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _amount,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*')),
                        ],
                        decoration:
                            const InputDecoration(hintText: 'Amount *'),
                        validator: (v) {
                          final n = double.tryParse((v ?? '').trim());
                          if (n == null || n <= 0) return 'Enter an amount';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SegmentedButton<VoucherMode>(
                        segments: const [
                          ButtonSegment(
                              value: VoucherMode.cash, label: Text('Cash')),
                          ButtonSegment(
                              value: VoucherMode.bank, label: Text('Bank')),
                        ],
                        selected: {_mode},
                        onSelectionChanged: (s) =>
                            setState(() => _mode = s.first),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _reference,
                  decoration: const InputDecoration(
                      hintText: 'Reference (cheque / bill no)'),
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
          child: Text(_isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
