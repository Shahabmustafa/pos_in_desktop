import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos/shared/app_icon.dart';

import '../../../../config/format.dart';
import '../../data/model/cash_register_model.dart';

/// Add / edit form for a manual cash movement. Pops a [CashEntry] on save.
class CashEntryFormDialog extends StatefulWidget {
  const CashEntryFormDialog({super.key, this.initial});

  final CashEntry? initial;

  @override
  State<CashEntryFormDialog> createState() => _CashEntryFormDialogState();
}

class _CashEntryFormDialogState extends State<CashEntryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date = widget.initial?.date ?? DateTime.now();
  late CashDirection _direction =
      widget.initial?.direction ?? CashDirection.cashOut;
  late final _amount = TextEditingController(
    text: widget.initial == null ? '' : widget.initial!.amount.toStringAsFixed(2),
  );
  late final _category =
      TextEditingController(text: widget.initial?.category ?? '');
  late final _description =
      TextEditingController(text: widget.initial?.description ?? '');

  bool get _isEdit => widget.initial?.id != null;

  @override
  void dispose() {
    _amount.dispose();
    _category.dispose();
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
    final model = (widget.initial ?? CashEntry(date: _date)).copyWith(
      date: _date,
      direction: _direction,
      amount: double.tryParse(_amount.text.trim()) ?? 0,
      category: _category.text.trim(),
      description: _description.text.trim(),
    );
    Navigator.pop(context, model);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Cash Entry' : 'Add Cash Entry'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: SegmentedButton<CashDirection>(
                        segments: const [
                          ButtonSegment(
                              value: CashDirection.cashIn, label: Text('In')),
                          ButtonSegment(
                              value: CashDirection.cashOut, label: Text('Out')),
                        ],
                        selected: {_direction},
                        onSelectionChanged: (s) =>
                            setState(() => _direction = s.first),
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
                  decoration: const InputDecoration(hintText: 'Amount *'),
                  validator: (v) {
                    final n = double.tryParse((v ?? '').trim());
                    if (n == null || n <= 0) return 'Enter an amount';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Autocomplete<String>(
                  initialValue: TextEditingValue(text: _category.text),
                  optionsBuilder: (t) {
                    final q = t.text.toLowerCase();
                    return CashEntry.categories
                        .where((c) => c.toLowerCase().contains(q));
                  },
                  onSelected: (v) => _category.text = v,
                  fieldViewBuilder: (context, controller, focus, onSubmit) {
                    controller.text = _category.text;
                    return TextFormField(
                      controller: controller,
                      focusNode: focus,
                      onChanged: (v) => _category.text = v,
                      decoration: const InputDecoration(
                        hintText: 'Category (e.g. Bank deposit)',
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _description,
                  maxLines: 2,
                  decoration: const InputDecoration(hintText: 'Description'),
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

/// Small dialog to set the opening cash float and its date.
class CashOpeningDialog extends StatefulWidget {
  const CashOpeningDialog({super.key, required this.initial});

  final CashAccount initial;

  @override
  State<CashOpeningDialog> createState() => _CashOpeningDialogState();
}

class _CashOpeningDialogState extends State<CashOpeningDialog> {
  final _formKey = GlobalKey<FormState>();
  late DateTime _date = widget.initial.openingDate;
  late final _amount = TextEditingController(
    text: widget.initial.openingBalance == 0
        ? ''
        : widget.initial.openingBalance.toStringAsFixed(2),
  );

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(DateTime(2001)) ? DateTime.now() : _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Opening cash'),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Cash already in the drawer before the system started '
                'tracking it.',
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _amount,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: const InputDecoration(hintText: 'Opening amount'),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'As of',
                    prefixIcon: AppIcon(AppIcons.event, size: 18),
                  ),
                  child: Text(Fmt.date(_date)),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            widget.initial.copyWith(
              openingBalance: double.tryParse(_amount.text.trim()) ?? 0,
              openingDate: _date,
            ),
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
