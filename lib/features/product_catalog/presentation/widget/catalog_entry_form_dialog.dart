import 'package:flutter/material.dart';

/// The values collected by [CatalogEntryFormDialog].
class CatalogEntryDraft {
  const CatalogEntryDraft({
    required this.name,
    required this.description,
    required this.isActive,
  });

  final String name;
  final String description;
  final bool isActive;
}

/// Generic add / edit form for a simple catalog entry (a category or an
/// inventory type). Pops a [CatalogEntryDraft] on save, `null` on cancel.
class CatalogEntryFormDialog extends StatefulWidget {
  const CatalogEntryFormDialog({
    super.key,
    required this.entityLabel,
    this.name,
    this.description,
    this.isActive = true,
    this.isEdit = false,
  });

  /// e.g. 'Category' or 'Inventory Type'.
  final String entityLabel;
  final String? name;
  final String? description;
  final bool isActive;
  final bool isEdit;

  @override
  State<CatalogEntryFormDialog> createState() => _CatalogEntryFormDialogState();
}

class _CatalogEntryFormDialogState extends State<CatalogEntryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.name ?? '');
  late final _description =
      TextEditingController(text: widget.description ?? '');
  late bool _isActive = widget.isActive;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      CatalogEntryDraft(
        name: _name.text.trim(),
        description: _description.text.trim(),
        isActive: _isActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title =
        '${widget.isEdit ? 'Edit' : 'Add'} ${widget.entityLabel}';
    return AlertDialog(
      title: Text(title),
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
          child: Text(widget.isEdit ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
