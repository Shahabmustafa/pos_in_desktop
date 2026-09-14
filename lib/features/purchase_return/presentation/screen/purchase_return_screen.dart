import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pos/shared/app_icon.dart';

import '../../../../config/format.dart';
import '../../../../shared/feature_ui.dart';
import '../../../../shared/receipt/receipt_printer.dart';
import '../../../../shared/receipt/sale_receipt.dart';
import '../../../purchase/data/model/purchase_model.dart';
import '../../data/datasource/purchase_return_datasource.dart';
import '../../data/model/purchase_return_item_model.dart';
import '../../data/model/purchase_return_model.dart';
import '../provider/purchase_return_provider.dart';

/// Purchase Return module — lists every purchase invoice; opening one shows its
/// detail on the right where the user ticks the lines / quantities to send back
/// to the supplier. Returning every line in full deletes the invoice; a partial
/// return shrinks it. Either way a `purchase_return` is recorded for Reports.
class PurchaseReturnScreen extends StatefulWidget {
  const PurchaseReturnScreen({super.key, this.provider});

  static const String routeName = '/purchase_return';

  final PurchaseReturnProvider? provider;

  @override
  State<PurchaseReturnScreen> createState() => _PurchaseReturnScreenState();
}

class _PurchaseReturnScreenState extends State<PurchaseReturnScreen> {
  late final PurchaseReturnProvider _provider =
      widget.provider ?? PurchaseReturnProvider();

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
    PurchaseModel invoice,
    List<PurchaseReturnSelection> selections,
    bool printReceipt,
  ) async {
    final full = selections.length == invoice.items.length &&
        selections.every((s) => (s.item.quantity - s.qty).abs() < 1e-6);

    final ok = await _provider.submitReturn(invoice, selections);
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

  /// Builds the A4 invoice for a just-recorded purchase return. Mirrors the
  /// per-line maths in `PurchaseReturnDataSource.returnFromInvoice`.
  ReceiptData _returnReceipt(
    PurchaseModel invoice,
    List<PurchaseReturnSelection> selections,
  ) {
    final items = [
      for (final s in selections)
        PurchaseReturnItemModel(
          productName: s.item.productName,
          quantity: s.qty,
          unitPrice: s.item.purchasePrice,
          discount: s.item.discount,
          tax: s.item.tax,
        ),
    ];
    final record = PurchaseReturnModel(
      returnDate: DateTime.now(),
      companyName: invoice.companyName,
      items: items,
    );
    final srcNo =
        invoice.invoiceNo.isEmpty ? '#${invoice.id ?? ''}' : invoice.invoiceNo;
    return ReceiptData(
      docType: 'PURCHASE RETURN',
      invoiceNo: '',
      date: record.returnDate,
      partyLabel: 'Supplier',
      partyName: invoice.companyName,
      extraInfo: [('Against', srcNo)],
      lines: [
        for (final it in record.items)
          ReceiptLine(
            name: it.productName,
            quantity: it.quantity,
            unitPrice: it.unitPrice,
            lineTotal: it.lineTotal,
            discountAmount: it.discountAmount,
          ),
      ],
      subtotal: record.subtotal,
      discountTotal: record.discountTotal,
      taxTotal: record.taxTotal,
      grandTotal: record.grandTotal,
      grandTotalLabel: 'RETURN TOTAL',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Return'),
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
                    saving: _provider.saving,
                    onClose: _provider.clearSelection,
                    onConfirm: (sels, printReceipt) =>
                        _confirmReturn(selected, sels, printReceipt),
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

  final PurchaseReturnProvider provider;

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
                title: 'Purchase Invoices',
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
              subtitle:
                  'View a purchase invoice, then choose the lines to send back',
              fillHeight: true,
              child: invoices.isEmpty
                  ? const EmptyState(
                      icon: AppIcons.keyboard_return_outlined,
                      title: 'No purchase invoices yet',
                    )
                  : ScrollableTable(
                      flexColumn: 2,
                      columns: const [
                        DataColumn(label: Text('Invoice #')),
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Supplier')),
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
                              DataCell(Text(inv.companyName.isEmpty
                                  ? '—'
                                  : inv.companyName)),
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
    required this.saving,
    required this.onClose,
    required this.onConfirm,
  });

  final PurchaseModel invoice;
  final bool saving;
  final VoidCallback onClose;
  final void Function(
          List<PurchaseReturnSelection> selections, bool printReceipt)
      onConfirm;

  @override
  State<_ReturnDetailPanel> createState() => _ReturnDetailPanelState();
}

class _ReturnDetailPanelState extends State<_ReturnDetailPanel> {
  late final List<bool> _checked;
  late final List<TextEditingController> _qtyCtrls;
  bool _printReceipt = true;

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

  List<PurchaseReturnSelection>? _collect() {
    final out = <PurchaseReturnSelection>[];
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
              '(not more than the bought quantity).'),
        ),
      );
      return;
    }
    widget.onConfirm(sels, _printReceipt);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final inv = widget.invoice;
    final sels = _collect() ?? const <PurchaseReturnSelection>[];
    final returnValue = sels.fold<double>(
        0, (a, s) => a + s.item.purchasePrice * s.qty);
    final full = sels.length == inv.items.length &&
        sels.every((s) => (s.item.quantity - s.qty).abs() < 1e-6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      inv.invoiceNo.isEmpty
                          ? 'Invoice #${inv.id}'
                          : inv.invoiceNo,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${Fmt.date(inv.date)}  ·  '
                      '${inv.companyName.isEmpty ? "No supplier" : inv.companyName}',
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
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: inv.items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final it = inv.items[i];
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                            it.productName.isEmpty
                                ? '(unnamed)'
                                : it.productName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            'Bought ${_qtyStr(it.quantity)} ${it.unit} · '
                            '${Fmt.money(it.purchasePrice)} each',
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
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
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
                    : const AppIcon(AppIcons.keyboard_return_outlined,
                        size: 18),
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
