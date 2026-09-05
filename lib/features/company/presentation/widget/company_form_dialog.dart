import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/model/company_model.dart';

/// Add / edit form for a company. Pops a [CompanyModel] on save, `null` on cancel.
class CompanyFormDialog extends StatefulWidget {
  const CompanyFormDialog({super.key, this.initial});

  final CompanyModel? initial;

  @override
  State<CompanyFormDialog> createState() => _CompanyFormDialogState();
}

class _CompanyFormDialogState extends State<CompanyFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _email = TextEditingController(text: widget.initial?.email ?? '');
  late final _address =
      TextEditingController(text: widget.initial?.address ?? '');
  late final _phone = TextEditingController(text: widget.initial?.phone ?? '');
  late final _openingBalance = TextEditingController(
    text: widget.initial == null
        ? ''
        : widget.initial!.openingBalance.toStringAsFixed(2),
  );
  late bool _isActive = widget.initial?.isActive ?? true;

  bool get _isEdit => widget.initial?.id != null;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _address.dispose();
    _phone.dispose();
    _openingBalance.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final model = (widget.initial ?? const CompanyModel(name: '')).copyWith(
      name: _name.text.trim(),
      email: _email.text.trim(),
      address: _address.text.trim(),
      phone: _phone.text.trim(),
      openingBalance: double.tryParse(_openingBalance.text.trim()) ?? 0,
      isActive: _isActive,
    );
    Navigator.pop(context, model);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Company' : 'Add Company'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'Name *'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: 'Email'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                        .hasMatch(v.trim());
                    return ok ? null : 'Enter a valid email';
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(hintText: 'Phone Number'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _address,
                  maxLines: 2,
                  decoration: const InputDecoration(hintText: 'Address'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _openingBalance,
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
