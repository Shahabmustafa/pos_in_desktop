import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos/shared/app_icon.dart';

import '../../../../config/format.dart';
import '../../../../shared/feature_ui.dart';
import '../../../../shared/receipt/receipt_printer.dart';
import '../../../../shared/receipt/sale_receipt.dart';
import '../../../../shared/searchable_dropdown.dart';
import '../../../bank/data/model/bank_head_model.dart';
import '../../../sale_invoice/data/model/sale_invoice_model.dart';
import '../../data/datasource/sale_return_datasource.dart';
import '../../data/model/sale_return_model.dart';
import '../provider/sale_return_provider.dart';

/// Sale Return module — lists every sale invoice; opening one shows its detail
/// on the right where the user ticks the lines / quantities to send back.
/// Returning every line in full deletes the invoice; a partial return shrinks
/// it. Either way a `sale_return` is recorded for Reports.
class SaleReturnScreen extends StatefulWidget {
  const SaleReturnScreen({super.key, this.provider});

  static const String routeName = '/sale_return';

  final SaleReturnProvider? provider;

  @override
  State<SaleReturnScreen> createState() => _SaleReturnScreenState();
}

class _SaleReturnScreenState extends State<SaleReturnScreen> {
  late final SaleReturnProvider _provider =
      widget.provider ?? SaleReturnProvider();

  @override
  void initState() {
    super.initState();
    _provider.load();
  }

  @override
  void dispose() {
    if (widget.provider == null) _provider.dispose();
    super.dispose();
  }

  Future<void> _confirmReturn(
    SaleInvoiceModel invoice,
    List<ReturnSelection> selections,
    int? bankHeadId,
    bool printReceipt,
  ) async {
    final full = selections.length == invoice.items.length &&
        selections.every(
            (s) => (s.item.quantity - s.qty).abs() < 1e-6);

    final ok = await _provider.submitReturn(invoice, selections,
        bankHeadId: bankHeadId);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(full
              ? 'Invoice returned in full and removed'
              : 'Return recorded and invoice updated'),
        ),
      );
      if (printReceipt) {
        unawaited(ReceiptPrinter.instance.printReceipt(
          context,
          buildReceiptPdf(_returnReceipt(invoice, selections)),
          onError: (msg) {
            if (mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(msg)));
            }
          },
        ));
      }
    } else if (_provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_provider.error!)),
      );
    }
  }

  /// Builds the 80mm receipt for a just-recorded sale return. Mirrors the
  /// per-line maths in `SaleReturnDataSource.returnFromInvoice` (flat discount
  /// pro-rated to the returned share).
  ReceiptData _returnReceipt(
    SaleInvoiceModel invoice,
    List<ReturnSelection> selections,
  ) {
    final items = [
      for (final s in selections)
        SaleReturnItemModel(
          productName: s.item.productName,
          quantity: s.qty,
          salePrice: s.item.salePrice,
          discount: s.item.discount,
          discountFlat: s.item.quantity <= 0
              ? 0
              : s.item.discountFlat * (s.qty / s.item.quantity),
          tax: s.item.tax,
        ),
    ];
    final record = SaleReturnModel(
      returnDate: DateTime.now(),
      customerName: invoice.customerName,
      items: items,
    );
    final srcNo =
        invoice.invoiceNo.isEmpty ? '#${invoice.id ?? ''}' : invoice.invoiceNo;
    return ReceiptData(
      docType: 'SALE RETURN',
      invoiceNo: '',
      date: record.returnDate,
      partyLabel: 'Customer',
      partyName: invoice.customerName.isEmpty ? 'Walk-in' : invoice.customerName,
      extraInfo: [('Against', srcNo)],
      lines: [
        for (final it in record.items)
          ReceiptLine(
            name: it.productName,
            quantity: it.quantity,
            unitPrice: it.salePrice,
            lineTotal: it.lineTotal,
            discountAmount: it.discountAmount,
          ),
      ],
      subtotal: record.subtotal,
      discountTotal: record.discountTotal,
      taxTotal: record.taxTotal,
      grandTotal: record.grandTotal,
      grandTotalLabel: 'REFUND TOTAL',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sale Return'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
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
          if (_provider.error != null && _provider.invoices.isEmpty) {
            return ErrorState(
                message: _provider.error!, onRetry: _provider.load);
          }

          final selected = _provider.selected;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _InvoiceList(provider: _provider)),
              if (selected != null) ...[
                const VerticalDivider(width: 1),
                SizedBox(
                  width: 460,
                  child: _ReturnDetailPanel(
                    key: ValueKey(selected.id),
                    invoice: selected,
                    banks: _provider.banks,
                    saving: _provider.saving,
                    onClose: _provider.clearSelection,
                    onConfirm: (sels, bankId, printReceipt) =>
                        _confirmReturn(selected, sels, bankId, printReceipt),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _InvoiceList extends StatelessWidget {
  const _InvoiceList({required this.provider});

  final SaleReturnProvider provider;

  @override
  Widget build(BuildContext context) {
    final invoices = provider.invoices;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatCardRow(
            cards: [
              StatCard(
                title: 'Sale Invoices',
                subtitle: '${provider.invoiceCount}',
              ),
              StatCard(
                title: 'Invoiced Value',
                subtitle: Fmt.money(provider.invoicedTotal),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SectionCard(
              title: 'Pick an invoice to return',
              subtitle: 'View a sale invoice, then choose the lines to send back',
              fillHeight: true,
              child: invoices.isEmpty
                  ? const EmptyState(
                      icon: AppIcons.assignment_return_outlined,
                      title: 'No sale invoices yet',
                    )
                  : ScrollableTable(
                      flexColumn: 2,
                      columns: const [
                        DataColumn(label: Text('Invoice #')),
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Customer')),
                        DataColumn(label: Text('Items'), numeric: true),
                        DataColumn(label: Text('Total'), numeric: true),
                        DataColumn(label: Text('')),
                      ],
                      rows: [
                        for (final inv in invoices)
                          DataRow(
                            selected: provider.selected?.id == inv.id,
                            cells: [
                              DataCell(Text(inv.invoiceNo.isEmpty
                                  ? '#${inv.id}'
                                  : inv.invoiceNo)),
                              DataCell(Text(Fmt.date(inv.date))),
                              DataCell(Text(inv.customerName.isEmpty
                                  ? '—'
                                  : inv.customerName)),
                              DataCell(Text('${inv.itemCount}')),
                              DataCell(Text(Fmt.money(inv.grandTotal))),
                              DataCell(
                                TextButton.icon(
                                  icon: const AppIcon(
                                      AppIcons.visibility_outlined, size: 18),
                                  label: const Text('View'),
                                  onPressed: () => provider.select(inv),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Right-hand panel: the invoice's lines, each with a tick + return-qty field,
/// and a Confirm Return button.
class _ReturnDetailPanel extends StatefulWidget {
  const _ReturnDetailPanel({
    super.key,
    required this.invoice,
    required this.banks,
    required this.saving,
    required this.onClose,
    required this.onConfirm,
  });

  final SaleInvoiceModel invoice;
  final List<BankHeadModel> banks;
  final bool saving;
  final VoidCallback onClose;
  final void Function(
          List<ReturnSelection> selections, int? bankHeadId, bool printReceipt)
      onConfirm;

  @override
  State<_ReturnDetailPanel> createState() => _ReturnDetailPanelState();
}

class _ReturnDetailPanelState extends State<_ReturnDetailPanel> {
  late final List<bool> _checked;
  late final List<TextEditingController> _qtyCtrls;
  int? _bankId;
  bool _printReceipt = true;

  /// What a line credits back for [qty] units — mirrors
  /// `SaleReturnItemModel.lineTotal` (per-line % + flat discount, then tax).
  static double _lineValue(SaleInvoiceItemModel it, double qty) {
    final gross = it.salePrice * qty;
    final flat =
        it.quantity <= 0 ? 0 : it.discountFlat * (qty / it.quantity);
    var disc = gross * it.discount / 100 + flat;
    if (disc < 0) disc = 0;
    if (disc > gross) disc = gross;
    return (gross - disc) * (1 + it.tax / 100);
  }

  @override
  void initState() {
    super.initState();
    final items = widget.invoice.items;
    // Nothing pre-selected — the user types how much of each line to send back.
    _checked = List<bool>.filled(items.length, false);
    _qtyCtrls = [for (final _ in items) TextEditingController()];
  }

  @override
  void dispose() {
    for (final c in _qtyCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  static String _qtyStr(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  /// Line info under the product name: sold qty, unit price and any discount /
  /// tax that was on the sale-invoice line.
  static String _lineSubtitle(SaleInvoiceItemModel it) {
    final parts = <String>[
      'Sold ${_qtyStr(it.quantity)} ${it.unit}',
      '${Fmt.money(it.salePrice)} each',
    ];
    if (it.discount > 0) parts.add('${_qtyStr(it.discount)}% disc');
    if (it.discountFlat > 0) parts.add('${Fmt.money(it.discountFlat)} off');
    if (it.tax > 0) parts.add('${_qtyStr(it.tax)}% tax');
    return parts.join(' · ');
  }

  /// Valid, ticked lines. Returns null if a ticked line has a bad quantity.
  List<ReturnSelection>? _collect() {
    final out = <ReturnSelection>[];
    final items = widget.invoice.items;
    for (var i = 0; i < items.length; i++) {
      if (!_checked[i]) continue;
      final q = double.tryParse(_qtyCtrls[i].text.trim());
      if (q == null || q <= 0 || q > items[i].quantity + 1e-6) return null;
      out.add((item: items[i], qty: q));
    }
    return out;
  }

  void _submit() {
    final sels = _collect();
    if (sels == null || sels.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a return quantity for at least one line '
              '(not more than the sold quantity).'),
        ),
      );
      return;
    }
    widget.onConfirm(sels, _bankId, _printReceipt);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final inv = widget.invoice;
    final sels = _collect() ?? const <ReturnSelection>[];
    final returnValue = sels.fold<double>(
        0, (a, s) => a + _lineValue(s.item, s.qty));
    final full = sels.length == inv.items.length &&
        sels.every((s) => (s.item.quantity - s.qty).abs() < 1e-6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inv.invoiceNo.isEmpty ? 'Invoice #${inv.id}' : inv.invoiceNo,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${Fmt.date(inv.date)}  ·  '
                      '${inv.customerName.isEmpty ? "No customer" : inv.customerName}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.outline),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                icon: const AppIcon(AppIcons.close),
                onPressed: widget.onClose,
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Lines
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: inv.items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final it = inv.items[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(
                  children: [
                    Checkbox(
                      value: _checked[i],
                      onChanged: widget.saving
                          ? null
                          : (v) => setState(() {
                                _checked[i] = v ?? false;
                                if (!_checked[i]) _qtyCtrls[i].clear();
                              }),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            it.productName.isEmpty ? '(unnamed)' : it.productName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            _lineSubtitle(it),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: scheme.outline),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 104,
                      child: TextField(
                        controller: _qtyCtrls[i],
                        enabled: !widget.saving,
                        textAlign: TextAlign.center,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]')),
                        ],
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'Return Qty',
                        ),
                        onChanged: (v) =>
                            setState(() => _checked[i] = v.trim().isNotEmpty),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      sels.isEmpty
                          ? 'Enter a return quantity to start'
                          : full
                              ? 'Full return — invoice will be removed'
                              : '${sels.length} line(s) · partial return',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: full ? scheme.error : scheme.outline,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    Fmt.money(returnValue),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              if (widget.banks.isNotEmpty) ...[
                const SizedBox(height: 12),
                SearchableDropdown<int>(
                  items: [for (final b in widget.banks) b.id!],
                  value: _bankId,
                  itemLabel: (id) => widget.banks
                      .firstWhere((b) => b.id == id,
                          orElse: () => const BankHeadModel(title: '—'))
                      .title,
                  hintText: 'Refund from bank (optional)',
                  includeNull: true,
                  nullLabel: 'No bank (cash)',
                  enabled: !widget.saving,
                  onChanged: (v) => setState(() => _bankId = v),
                ),
              ],
              const SizedBox(height: 4),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: widget.saving
                    ? null
                    : () => setState(() => _printReceipt = !_printReceipt),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _printReceipt,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        onChanged: widget.saving
                            ? null
                            : (v) =>
                                setState(() => _printReceipt = v ?? false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('Print receipt',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant)),
                  ]),
                ),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: widget.saving ? null : _submit,
                icon: widget.saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const AppIcon(AppIcons.keyboard_return_outlined, size: 18),
                label: Text(widget.saving ? 'Working…' : 'Confirm Return'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFC62828),
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
