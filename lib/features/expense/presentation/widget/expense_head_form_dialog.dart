import 'package:flutter/material.dart';

import '../../data/model/expense_head_model.dart';

/// Add / edit form for an expense head. Pops an [ExpenseHeadModel] on save.
class ExpenseHeadFormDialog extends StatefulWidget {
  const ExpenseHeadFormDialog({super.key, this.initial});

  final ExpenseHeadModel? initial;

  @override
  State<ExpenseHeadFormDialog> createState() => _ExpenseHeadFormDialogState();
}

class _ExpenseHeadFormDialogState extends State<ExpenseHeadFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _description =
      TextEditingController(text: widget.initial?.description ?? '');
  late bool _isActive = widget.initial?.isActive ?? true;

  bool get _isEdit => widget.initial?.id != null;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final model = (widget.initial ?? const ExpenseHeadModel(name: '')).copyWith(
      name: _name.text.trim(),
      description: _description.text.trim(),
      isActive: _isActive,
    );
    Navigator.pop(context, model);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Expense Head' : 'Add Expense Head'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
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
                controller: _description,
                maxLines: 2,
                decoration: const InputDecoration(hintText: 'Description'),
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
