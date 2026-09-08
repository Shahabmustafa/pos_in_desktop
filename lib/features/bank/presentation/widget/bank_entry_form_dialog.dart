import 'package:flutter/material.dart';
import 'package:pos/shared/app_icon.dart';
import 'package:flutter/services.dart';

import '../../../../config/format.dart';
import '../../../../shared/searchable_dropdown.dart';
import '../../data/model/bank_entry_model.dart';
import '../../data/model/bank_head_model.dart';

/// Add / edit form for a bank entry. Pops a [BankEntryModel] on save.
class BankEntryFormDialog extends StatefulWidget {
  const BankEntryFormDialog({
    super.key,
    required this.heads,
    this.initial,
    this.presetHeadId,
  });

  final List<BankHeadModel> heads;
  final BankEntryModel? initial;
  final int? presetHeadId;

  @override
  State<BankEntryFormDialog> createState() => _BankEntryFormDialogState();
}

class _BankEntryFormDialogState extends State<BankEntryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late int? _headId = widget.initial?.bankHeadId ??
      widget.presetHeadId ??
      (widget.heads.isEmpty ? null : widget.heads.first.id);
  late DateTime _date = widget.initial?.date ?? DateTime.now();
  late BankEntryType _type = widget.initial?.type ?? BankEntryType.deposit;
  late final _amount = TextEditingController(
    text: widget.initial == null
        ? ''
        : widget.initial!.amount.toStringAsFixed(2),
  );
  late final _description =
      TextEditingController(text: widget.initial?.description ?? '');

  bool get _isEdit => widget.initial?.id != null;

  @override
  void dispose() {
    _amount.dispose();
    _description.dispose();
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_headId == null) return;
    final model = (widget.initial ??
            BankEntryModel(
              bankHeadId: _headId!,
              date: _date,
              type: _type,
              amount: 0,
            ))
        .copyWith(
      bankHeadId: _headId,
      date: _date,
      type: _type,
      amount: double.tryParse(_amount.text.trim()) ?? 0,
      description: _description.text.trim(),
    );
    Navigator.pop(context, model);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Bank Entry' : 'Add Bank Entry'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SearchableDropdown<int>(
                  items: [for (final h in widget.heads) h.id!],
                  value: _headId,
                  hintText: 'Bank Head *',
                  itemLabel: (id) => widget.heads
                      .firstWhere((h) => h.id == id,
                          orElse: () => const BankHeadModel(title: '—'))
                      .title,
                  onChanged: (v) => setState(() => _headId = v),
                  validator: (v) => v == null ? 'Select a bank head' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickDate,
                        child: InputDecorator(
                          decoration:
                              const InputDecoration(hintText: 'Date', prefixIcon: AppIcon(AppIcons.event, size: 18)),
                          child: Text(Fmt.date(_date)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SegmentedButton<BankEntryType>(
                        segments: const [
                          ButtonSegment(
                              value: BankEntryType.deposit,
                              label: Text('Deposit')),
                          ButtonSegment(
                              value: BankEntryType.withdraw,
                              label: Text('Withdraw')),
                        ],
                        selected: {_type},
                        onSelectionChanged: (s) =>
                            setState(() => _type = s.first),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amount,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  decoration: const InputDecoration(
                    hintText: 'Amount *',
                  ),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').trim());
                    if (n == null || n <= 0) return 'Enter an amount';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  maxLines: 2,
                  decoration:
                      const InputDecoration(hintText: 'Description'),
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
          onPressed: widget.heads.isEmpty ? null : _submit,
          child: Text(_isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
