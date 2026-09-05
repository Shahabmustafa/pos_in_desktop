import 'package:flutter/material.dart';
import 'package:pos/shared/app_icon.dart';
import 'package:flutter/services.dart';

import '../../../../config/format.dart';
import '../../../../shared/searchable_dropdown.dart';
import '../../data/model/named_ref.dart';
import '../../data/model/stock_item_model.dart';

const _units = ['pcs', 'kg', 'gm', 'ltr', 'ml', 'box', 'dozen', 'pack'];

/// Add / edit form for a stock item. Pops a [StockItemModel] on save.
///
/// The company, category and inventory-type pickers are fed from their master
/// tables ([companies], [categories], [inventoryTypes]) and the item stores the
/// selected row's id.
class StockItemFormDialog extends StatefulWidget {
  const StockItemFormDialog({
    super.key,
    this.initial,
    this.companies = const [],
    this.categories = const [],
    this.inventoryTypes = const [],
  });

  final StockItemModel? initial;
  final List<NamedRef> companies;
  final List<NamedRef> categories;
  final List<NamedRef> inventoryTypes;

  @override
  State<StockItemFormDialog> createState() => _StockItemFormDialogState();
}

class _StockItemFormDialogState extends State<StockItemFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final _barcode =
      TextEditingController(text: widget.initial?.barcode ?? '');
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _sku = TextEditingController(text: widget.initial?.sku ?? '');
  late final _sale = TextEditingController(
      text: widget.initial == null ? '' : _num(widget.initial!.salePrice));
  late final _purchase = TextEditingController(
      text: widget.initial == null ? '' : _num(widget.initial!.purchasePrice));
  late final _discount = TextEditingController(
      text: widget.initial == null ? '' : _num(widget.initial!.discount));
  late final _tax = TextEditingController(
      text: widget.initial == null ? '' : _num(widget.initial!.tax));
  late final _quantity = TextEditingController(
      text: widget.initial == null ? '' : _num(widget.initial!.quantity));

  late String _unit = widget.initial?.unit ?? 'pcs';
  late NamedRef? _company = _match(
      widget.companies, widget.initial?.companyId, widget.initial?.companyName);
  late NamedRef? _category = _match(
      widget.categories, widget.initial?.categoryId, widget.initial?.category);
  late NamedRef? _inventoryType = _match(widget.inventoryTypes,
      widget.initial?.inventoryTypeId, widget.initial?.inventoryType);
  late DateTime? _expiry = widget.initial?.expiryDate;
  late bool _isActive = widget.initial?.isActive ?? true;

  bool get _isEdit => widget.initial?.id != null;

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  /// Resolves the currently selected row from [list] by id, then by name.
  /// Falls back to a synthetic [NamedRef] so an id whose row was deactivated or
  /// deleted still shows its stored name.
  static NamedRef? _match(List<NamedRef> list, int? id, String? name) {
    final label = (name ?? '').trim();
    if (id != null) {
      for (final r in list) {
        if (r.id == id) return r;
      }
      if (label.isNotEmpty) return NamedRef(id: id, name: label);
    }
    if (label.isNotEmpty) {
      for (final r in list) {
        if (r.name.toLowerCase() == label.toLowerCase()) return r;
      }
    }
    return null;
  }

  /// Ensure the current selection is in the list so it shows as selected.
  List<NamedRef> _withCurrent(List<NamedRef> base, NamedRef? current) {
    if (current == null || base.contains(current)) return base;
    return [current, ...base];
  }

  @override
  void dispose() {
    _barcode.dispose();
    _name.dispose();
    _sku.dispose();
    _sale.dispose();
    _purchase.dispose();
    _discount.dispose();
    _tax.dispose();
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _expiry = picked);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final model = (widget.initial ?? const StockItemModel(name: '')).copyWith(
      barcode: _barcode.text.trim(),
      name: _name.text.trim(),
      sku: _sku.text.trim(),
      salePrice: double.tryParse(_sale.text.trim()) ?? 0,
      purchasePrice: double.tryParse(_purchase.text.trim()) ?? 0,
      quantity: double.tryParse(_quantity.text.trim()) ?? 0,
      discount: double.tryParse(_discount.text.trim()) ?? 0,
      tax: double.tryParse(_tax.text.trim()) ?? 0,
      expiryDate: _expiry,
      unit: _unit,
      companyId: _company?.id,
      companyName: _company?.name ?? '',
      inventoryTypeId: _inventoryType?.id,
      inventoryType: _inventoryType?.name ?? '',
      categoryId: _category?.id,
      category: _category?.name ?? '',
      isActive: _isActive,
    );
    Navigator.pop(context, model);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit Product' : 'Add Product'),
      content: SizedBox(
        width: 480,
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
                  decoration: const InputDecoration(hintText: 'Product name *'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Product name is required'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: TextFormField(
                      controller: _barcode,
                      decoration: const InputDecoration(hintText: 'Barcode'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _sku,
                      decoration: const InputDecoration(hintText: 'SKU'),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                SearchableDropdown<NamedRef>(
                  items: _withCurrent(widget.companies, _company),
                  value: _company,
                  itemLabel: (r) => r.name,
                  hintText: 'Company',
                  onChanged: (v) => setState(() => _company = v),
                ),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: SearchableDropdown<NamedRef>(
                      items:
                          _withCurrent(widget.inventoryTypes, _inventoryType),
                      value: _inventoryType,
                      itemLabel: (r) => r.name,
                      hintText: 'Inventory type',
                      onChanged: (v) => setState(() => _inventoryType = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SearchableDropdown<NamedRef>(
                      items: _withCurrent(widget.categories, _category),
                      value: _category,
                      itemLabel: (r) => r.name,
                      hintText: 'Category',
                      onChanged: (v) => setState(() => _category = v),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _numField(_purchase, 'Purchase price')),
                  const SizedBox(width: 12),
                  Expanded(child: _numField(_sale, 'Sale price')),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _numField(_discount, 'Disc %')),
                  const SizedBox(width: 12),
                  Expanded(child: _numField(_tax, 'Tax %')),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: _numField(_quantity,
                        _isEdit ? 'Stock quantity' : 'Opening stock'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SearchableDropdown<String>(
                      items: _units,
                      value: _unit,
                      hintText: 'Unit',
                      onChanged: (v) => setState(() => _unit = v ?? 'pcs'),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickExpiry,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          hintText: 'Expiry date',
                          prefixIcon: const AppIcon(AppIcons.event, size: 18),
                          suffixIcon: _expiry == null
                              ? null
                              : IconButton(
                                  icon: const AppIcon(AppIcons.clear, size: 18),
                                  onPressed: () =>
                                      setState(() => _expiry = null),
                                ),
                        ),
                        child:
                            Text(_expiry == null ? '—' : Fmt.date(_expiry!)),
                      ),
                    ),
                  ),
                ]),
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

  Widget _numField(TextEditingController c, String hint) {
    return TextFormField(
      controller: c,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      decoration: InputDecoration(hintText: hint),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return null;
        return double.tryParse(v.trim()) == null ? 'Number' : null;
      },
    );
  }
}
