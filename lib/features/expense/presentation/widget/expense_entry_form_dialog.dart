import 'package:flutter/material.dart';
import 'package:pos/shared/app_icon.dart';
import 'package:flutter/services.dart';

import '../../../../config/format.dart';
import '../../../../shared/searchable_dropdown.dart';
import '../../data/model/expense_entry_model.dart';
import '../../data/model/expense_head_model.dart';

/// Add / edit form for an expense entry. Pops an [ExpenseEntryModel] on save.
class ExpenseEntryFormDialog extends StatefulWidget {
  const ExpenseEntryFormDialog({
    super.key,
    required this.heads,
    this.initial,
    this.presetHeadId,
  });

  final List<ExpenseHeadModel> heads;
  final ExpenseEntryModel? initial;
  final int? presetHeadId;

  @override
  State<ExpenseEntryFormDialog> createState() => _ExpenseEntryFormDialogState();
}

class _ExpenseEntryFormDialogState extends State<ExpenseEntryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late int? _headId = widget.initial?.expenseHeadId ??
      widget.presetHeadId ??
      (widget.heads.isEmpty ? null : widget.heads.first.id);
  late DateTime _date = widget.initial?.date ?? DateTime.now();
  late ExpensePaymentMode _mode =
      widget.initial?.paymentMode ?? ExpensePaymentMode.cash;
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
            ExpenseEntryModel(
              expenseHeadId: _headId!,
              date: _date,
              amount: 0,
            ))
        .copyWith(
      expenseHeadId: _headId,
      date: _date,
      amount: double.tryParse(_amount.text.trim()) ?? 0,
      paymentMode: _mode,
      description: _description.text.trim(),
    );
    Navigator.pop(context, model);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Expense Entry' : 'Add Expense Entry'),
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
                  hintText: 'Expense Head *',
                  itemLabel: (id) => widget.heads
                      .firstWhere((h) => h.id == id,
                          orElse: () => const ExpenseHeadModel(name: '—'))
                      .name,
                  onChanged: (v) => setState(() => _headId = v),
                  validator: (v) => v == null ? 'Select an expense head' : null,
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
                      child: SegmentedButton<ExpensePaymentMode>(
                        segments: const [
                          ButtonSegment(
                              value: ExpensePaymentMode.cash,
                              label: Text('Cash')),
                          ButtonSegment(
                              value: ExpensePaymentMode.bank,
                              label: Text('Bank')),
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
                  controller: _amount,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
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
