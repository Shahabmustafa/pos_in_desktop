import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pos/shared/app_icon.dart';

import '../../../../shared/feature_ui.dart';
import '../../../login/data/permissions.dart';
import '../../../login/presentation/access_scope.dart';
import '../../data/model/receipt_settings_model.dart';
import '../provider/receipt_settings_provider.dart';
import '../widget/receipt_preview.dart';

/// Receipt Settings: edit the shop header printed on every 80mm thermal
/// receipt and toggle which invoice fields appear on it. A live preview on the
/// right updates as you type.
class ReceiptSettingsScreen extends StatefulWidget {
  const ReceiptSettingsScreen({super.key, this.provider});

  static const String routeName = '/receipt-settings';

  final ReceiptSettingsProvider? provider;

  @override
  State<ReceiptSettingsScreen> createState() => _ReceiptSettingsScreenState();
}

class _ReceiptSettingsScreenState extends State<ReceiptSettingsScreen> {
  late final ReceiptSettingsProvider _provider =
      widget.provider ?? ReceiptSettingsProvider();

  final _name = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _footer = TextEditingController();

  Uint8List? _logo;
  late bool _showLogo;
  late bool _showInvoiceNo;
  late bool _showDate;
  late bool _showParty;
  late bool _showNotes;
  late bool _showItemDiscount;
  late bool _showDiscountTotal;
  late bool _showTaxTotal;
  late bool _showPaidBalance;
  late bool _showItemCount;
  late bool _showFooter;

  @override
  void initState() {
    super.initState();
    _readFrom(_provider.settings);
    _provider.addListener(_onProvider);
    _provider.load();
  }

  @override
  void dispose() {
    _provider.removeListener(_onProvider);
    if (widget.provider == null) _provider.dispose();
    _name.dispose();
    _address.dispose();
    _phone.dispose();
    _footer.dispose();
    super.dispose();
  }

  /// When the provider finishes (re)loading, refresh the form from the server
  /// copy — but leave a form the user is mid-edit alone.
  void _onProvider() {
    if (_provider.loading || _provider.saving) return;
    if (!_dirty) _apply(_provider.settings);
  }

  void _apply(ReceiptSettingsModel s) {
    _readFrom(s);
    if (mounted) setState(() {});
  }

  void _readFrom(ReceiptSettingsModel s) {
    _name.text = s.businessName;
    _address.text = s.businessAddress;
    _phone.text = s.businessPhone;
    _footer.text = s.footerText;
    _logo = s.logo;
    _showLogo = s.showLogo;
    _showInvoiceNo = s.showInvoiceNo;
    _showDate = s.showDate;
    _showParty = s.showParty;
    _showNotes = s.showNotes;
    _showItemDiscount = s.showItemDiscount;
    _showDiscountTotal = s.showDiscountTotal;
    _showTaxTotal = s.showTaxTotal;
    _showPaidBalance = s.showPaidBalance;
    _showItemCount = s.showItemCount;
    _showFooter = s.showFooter;
  }

  ReceiptSettingsModel get _model => ReceiptSettingsModel(
        businessName: _name.text.trim(),
        businessAddress: _address.text.trim(),
        businessPhone: _phone.text.trim(),
        footerText: _footer.text.trim(),
        logo: _logo,
        showLogo: _showLogo,
        showInvoiceNo: _showInvoiceNo,
        showDate: _showDate,
        showParty: _showParty,
        showNotes: _showNotes,
        showItemDiscount: _showItemDiscount,
        showDiscountTotal: _showDiscountTotal,
        showTaxTotal: _showTaxTotal,
        showPaidBalance: _showPaidBalance,
        showItemCount: _showItemCount,
        showFooter: _showFooter,
      );

  bool get _dirty => !_model.sameAs(_provider.settings);

  Future<void> _pickLogo() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Choose a logo image',
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final bytes = result.files.first.bytes;
    if (bytes == null) return;
    if (bytes.lengthInBytes > 1024 * 1024) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logo is too large — pick an image under 1 MB.'),
        ),
      );
      return;
    }
    setState(() => _logo = bytes);
  }

  Future<void> _save() async {
    final ok = await _provider.save(_model);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Receipt settings saved'
            : _provider.error ?? 'Could not save receipt settings'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = AccessScope.of(context).can('receipt_settings', PermAction.edit);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Settings'),
        actions: [
          IconButton(
            tooltip: 'Reload',
            icon: const AppIcon(AppIcons.refresh),
            onPressed: _provider.load,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListenableBuilder(
        listenable: _provider,
        builder: (context, _) {
          if (_provider.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_provider.error != null && !_dirty) {
            return ErrorState(
                message: _provider.error!, onRetry: _provider.load);
          }

          return LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              final form = _Form(
                nameController: _name,
                addressController: _address,
                phoneController: _phone,
                footerController: _footer,
                enabled: canEdit,
                onChanged: () => setState(() {}),
                logo: _logo,
                onPickLogo: _pickLogo,
                onRemoveLogo: () => setState(() => _logo = null),
                showLogo: _showLogo,
                showInvoiceNo: _showInvoiceNo,
                showDate: _showDate,
                showParty: _showParty,
                showNotes: _showNotes,
                showItemDiscount: _showItemDiscount,
                showDiscountTotal: _showDiscountTotal,
                showTaxTotal: _showTaxTotal,
                showPaidBalance: _showPaidBalance,
                showItemCount: _showItemCount,
                showFooter: _showFooter,
                onToggle: (field, value) => setState(() {
                  switch (field) {
                    case _Toggle.invoiceNo:
                      _showInvoiceNo = value;
                    case _Toggle.date:
                      _showDate = value;
                    case _Toggle.party:
                      _showParty = value;
                    case _Toggle.notes:
                      _showNotes = value;
                    case _Toggle.itemDiscount:
                      _showItemDiscount = value;
                    case _Toggle.discountTotal:
                      _showDiscountTotal = value;
                    case _Toggle.taxTotal:
                      _showTaxTotal = value;
                    case _Toggle.paidBalance:
                      _showPaidBalance = value;
                    case _Toggle.itemCount:
                      _showItemCount = value;
                    case _Toggle.footer:
                      _showFooter = value;
                    case _Toggle.logo:
                      _showLogo = value;
                  }
                }),
                canEdit: canEdit,
                dirty: _dirty,
                saving: _provider.saving,
                onSave: _save,
                onReset: () => _apply(_provider.settings),
              );

              final preview = ReceiptPreview(settings: _model);

              if (!wide) {
                return ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    _PreviewCard(child: preview),
                    const SizedBox(height: 16),
                    form,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 16, 12, 24),
                      child: form,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 16, 20, 24),
                    child: SizedBox(
                      width: 320,
                      child: _PreviewCard(child: preview),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Live preview',
      subtitle: '80mm thermal receipt',
      child: Center(child: child),
    );
  }
}

enum _Toggle {
  logo,
  invoiceNo,
  date,
  party,
  notes,
  itemDiscount,
  discountTotal,
  taxTotal,
  paidBalance,
  itemCount,
  footer,
}

class _Form extends StatelessWidget {
  const _Form({
    required this.nameController,
    required this.addressController,
    required this.phoneController,
    required this.footerController,
    required this.enabled,
    required this.onChanged,
    required this.logo,
    required this.onPickLogo,
    required this.onRemoveLogo,
    required this.showLogo,
    required this.showInvoiceNo,
    required this.showDate,
    required this.showParty,
    required this.showNotes,
    required this.showItemDiscount,
    required this.showDiscountTotal,
    required this.showTaxTotal,
    required this.showPaidBalance,
    required this.showItemCount,
    required this.showFooter,
    required this.onToggle,
    required this.canEdit,
    required this.dirty,
    required this.saving,
    required this.onSave,
    required this.onReset,
  });

  final TextEditingController nameController;
  final TextEditingController addressController;
  final TextEditingController phoneController;
  final TextEditingController footerController;
  final bool enabled;
  final VoidCallback onChanged;

  final Uint8List? logo;
  final Future<void> Function() onPickLogo;
  final VoidCallback onRemoveLogo;
  final bool showLogo;

  final bool showInvoiceNo;
  final bool showDate;
  final bool showParty;
  final bool showNotes;
  final bool showItemDiscount;
  final bool showDiscountTotal;
  final bool showTaxTotal;
  final bool showPaidBalance;
  final bool showItemCount;
  final bool showFooter;
  final void Function(_Toggle field, bool value) onToggle;

  final bool canEdit;
  final bool dirty;
  final bool saving;
  final Future<void> Function() onSave;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionCard(
          title: 'Business header',
          subtitle: 'Printed at the top of every receipt. '
              'Leave a line blank to hide it.',
          child: Column(
            children: [
              _LogoPicker(
                logo: logo,
                enabled: enabled,
                onPick: onPickLogo,
                onRemove: onRemoveLogo,
              ),
              const SizedBox(height: 16),
              _Field(
                controller: nameController,
                label: 'Business name',
                enabled: enabled,
                onChanged: onChanged,
                capitalize: true,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: addressController,
                label: 'Address',
                enabled: enabled,
                onChanged: onChanged,
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: phoneController,
                label: 'Phone',
                enabled: enabled,
                onChanged: onChanged,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              _Field(
                controller: footerController,
                label: 'Footer line',
                enabled: enabled,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Show on receipt',
          subtitle: 'Tick a field to print it. Unticked fields are left off '
              'every receipt.',
          padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
          child: Column(
            children: [
              _ToggleTile(
                title: 'Logo',
                subtitle: 'Only prints when a logo is uploaded',
                value: showLogo,
                enabled: enabled,
                onChanged: (v) => onToggle(_Toggle.logo, v),
              ),
              _ToggleTile(
                title: 'Invoice / return number',
                value: showInvoiceNo,
                enabled: enabled,
                onChanged: (v) => onToggle(_Toggle.invoiceNo, v),
              ),
              _ToggleTile(
                title: 'Date & time',
                value: showDate,
                enabled: enabled,
                onChanged: (v) => onToggle(_Toggle.date, v),
              ),
              _ToggleTile(
                title: 'Customer / supplier name',
                value: showParty,
                enabled: enabled,
                onChanged: (v) => onToggle(_Toggle.party, v),
              ),
              _ToggleTile(
                title: 'Invoice notes',
                subtitle: 'Only prints when the invoice has notes',
                value: showNotes,
                enabled: enabled,
                onChanged: (v) => onToggle(_Toggle.notes, v),
              ),
              _ToggleTile(
                title: 'Per-item discount line',
                value: showItemDiscount,
                enabled: enabled,
                onChanged: (v) => onToggle(_Toggle.itemDiscount, v),
              ),
              _ToggleTile(
                title: 'Discount total',
                value: showDiscountTotal,
                enabled: enabled,
                onChanged: (v) => onToggle(_Toggle.discountTotal, v),
              ),
              _ToggleTile(
                title: 'Tax total',
                value: showTaxTotal,
                enabled: enabled,
                onChanged: (v) => onToggle(_Toggle.taxTotal, v),
              ),
              _ToggleTile(
                title: 'Paid & balance',
                subtitle: 'Sale invoice only',
                value: showPaidBalance,
                enabled: enabled,
                onChanged: (v) => onToggle(_Toggle.paidBalance, v),
              ),
              _ToggleTile(
                title: 'Item / unit count',
                value: showItemCount,
                enabled: enabled,
                onChanged: (v) => onToggle(_Toggle.itemCount, v),
              ),
              _ToggleTile(
                title: 'Footer line',
                value: showFooter,
                enabled: enabled,
                onChanged: (v) => onToggle(_Toggle.footer, v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            if (dirty && !saving)
              TextButton(
                onPressed: onReset,
                child: const Text('Discard changes'),
              ),
            const Spacer(),
            FilledButton.icon(
              onPressed: (canEdit && dirty && !saving) ? onSave : null,
              icon: saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const AppIcon(AppIcons.save_outlined),
              label: Text(saving ? 'Saving...' : 'Save changes'),
            ),
          ],
        ),
        if (!canEdit)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'You can view these settings but not change them.',
              style: TextStyle(color: scheme.outline, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.enabled,
    required this.onChanged,
    this.maxLines = 1,
    this.capitalize = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final bool enabled;
  final VoidCallback onChanged;
  final int maxLines;
  final bool capitalize;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textCapitalization:
          capitalize ? TextCapitalization.words : TextCapitalization.sentences,
      decoration: InputDecoration(labelText: label),
      onChanged: (_) => onChanged(),
    );
  }
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.title,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      value: value,
      onChanged: enabled ? onChanged : null,
    );
  }
}

/// Logo thumbnail + upload / change / remove buttons.
class _LogoPicker extends StatelessWidget {
  const _LogoPicker({
    required this.logo,
    required this.enabled,
    required this.onPick,
    required this.onRemove,
  });

  final Uint8List? logo;
  final bool enabled;
  final Future<void> Function() onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasLogo = logo != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: hasLogo
              ? Image.memory(logo!, fit: BoxFit.contain)
              : Center(
                  child: AppIcon(AppIcons.print_outlined,
                      color: scheme.outline, size: 24),
                ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Logo',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                'PNG or JPG, under 1 MB. Printed centred at the top of the '
                'receipt.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.outline),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: enabled ? onPick : null,
                    icon: const AppIcon(AppIcons.download, size: 16),
                    label: Text(hasLogo ? 'Change' : 'Upload logo'),
                  ),
                  if (hasLogo) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: enabled ? onRemove : null,
                      child: const Text('Remove'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
