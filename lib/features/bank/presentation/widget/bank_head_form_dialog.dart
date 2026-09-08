import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/model/bank_head_model.dart';

/// Add / edit form for a bank head. Pops a [BankHeadModel] on save.
class BankHeadFormDialog extends StatefulWidget {
  const BankHeadFormDialog({super.key, this.initial});

  final BankHeadModel? initial;

  @override
  State<BankHeadFormDialog> createState() => _BankHeadFormDialogState();
}

class _BankHeadFormDialogState extends State<BankHeadFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.initial?.title ?? '');
  late final _bankName =
      TextEditingController(text: widget.initial?.bankName ?? '');
  late final _accountNumber =
      TextEditingController(text: widget.initial?.accountNumber ?? '');
  late final _opening = TextEditingController(
    text: widget.initial == null
        ? ''
        : widget.initial!.openingBalance.toStringAsFixed(2),
  );
  late bool _isActive = widget.initial?.isActive ?? true;

  bool get _isEdit => widget.initial?.id != null;

  @override
  void dispose() {
    _title.dispose();
    _bankName.dispose();
    _accountNumber.dispose();
    _opening.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final model = (widget.initial ?? const BankHeadModel(title: '')).copyWith(
      title: _title.text.trim(),
      bankName: _bankName.text.trim(),
      accountNumber: _accountNumber.text.trim(),
      openingBalance: double.tryParse(_opening.text.trim()) ?? 0,
      isActive: _isActive,
    );
    Navigator.pop(context, model);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Bank Head' : 'Add Bank Head'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _title,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration:
                      const InputDecoration(hintText: 'Account Title *'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Title is required'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _bankName,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'Bank Name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _accountNumber,
                  decoration:
                      const InputDecoration(hintText: 'Account Number'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _opening,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true, signed: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^-?\d*\.?\d*')),
                  ],
                  decoration: const InputDecoration(
                    hintText: 'Opening Balance',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    return double.tryParse(v.trim()) == null
                        ? 'Enter a number'
                        : null;
                  },
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active'),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
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
