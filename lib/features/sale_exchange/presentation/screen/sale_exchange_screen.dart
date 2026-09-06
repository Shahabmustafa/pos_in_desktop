import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pos/shared/app_icon.dart';

import '../../../../config/format.dart';
import '../../../../shared/feature_ui.dart';
import '../../../../shared/pos_invoice_builder.dart';
import '../../../../shared/receipt/receipt_printer.dart';
import '../../../../shared/receipt/sale_receipt.dart';
import '../../../sale_invoice/data/model/sale_invoice_model.dart';
import '../../../sale_invoice/data/model/sale_invoice_refs.dart';
import '../provider/sale_exchange_provider.dart';

const _accent = Color(0xFF6A1B9A);

/// Sale Exchange — lists every sale invoice; opening one shows the Sale-Invoice
/// cart UI pre-loaded with that invoice's items. Removing a line drops it from
/// the invoice, adding one adds it; Save Exchange rewrites the invoice (stock
/// and the customer balance follow) and logs a `sale_exchange` row.
class SaleExchangeScreen extends StatefulWidget {
  const SaleExchangeScreen({super.key, this.provider});

  static const String routeName = '/sale_exchange';

  final SaleExchangeProvider? provider;

  @override
  State<SaleExchangeScreen> createState() => _SaleExchangeScreenState();
}

class _SaleExchangeScreenState extends State<SaleExchangeScreen> {
  late final SaleExchangeProvider _provider =
      widget.provider ?? SaleExchangeProvider();

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

  Future<bool> _save(SaleInvoiceModel invoice, PosInvoiceDraft draft) async {
    final items = [
      for (final l in draft.lines)
        SaleInvoiceItemModel(
          productId: l.product.id < 0 ? null : l.product.id,
          productName: l.product.name,
          barcode: l.product.barcode,
          unit: l.product.unit,
          quantity: l.quantity,
          salePrice: l.price,
          purchasePrice: l.product.purchasePrice,
          discount: l.discount,
          discountFlat: l.discountFlat,
          tax: l.tax,
        ),
    ];
    final ok = await _provider.applyExchange(invoice, items);
    if (!mounted) return ok;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice exchanged')),
      );
      if (draft.printReceipt) {
        final exchanged = invoice.copyWith(items: items);
        unawaited(ReceiptPrinter.instance.printReceipt(
          context,
          buildReceiptPdf(ReceiptData(
            docType: 'SALE EXCHANGE',
            invoiceNo: exchanged.invoiceNo.isNotEmpty
                ? exchanged.invoiceNo
                : '#${exchanged.id ?? ''}',
            date: exchanged.date,
            partyLabel: 'Customer',
            partyName: exchanged.customerName.isEmpty
                ? 'Walk-in'
                : exchanged.customerName,
            lines: [
              for (final it in exchanged.items)
                ReceiptLine(
                  name: it.productName,
                  quantity: it.quantity,
                  unitPrice: it.salePrice,
                  lineTotal: it.lineTotal,
                  discountAmount: it.discountAmount,
                ),
            ],
            subtotal: exchanged.subtotal,
            discountTotal: exchanged.discountTotal,
            taxTotal: exchanged.taxTotal,
            grandTotal: exchanged.grandTotal,
          )),
          onError: (msg) {
            if (mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(msg)));
            }
          },
        ));
      }
      _provider.clearSelection();
    } else if (_provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_provider.error!)),
      );
    }
    return ok;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        if (_provider.loading) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (_provider.error != null && _provider.invoices.isEmpty) {
          return Scaffold(
            body: ErrorState(
                message: _provider.error!, onRetry: _provider.load),
          );
        }

        final selected = _provider.selected;
        if (selected != null) {
          return _ExchangeBuilder(
            key: ValueKey(selected.id),
            invoice: selected,
            products: _provider.products,
            saving: _provider.saving,
            onBack: _provider.clearSelection,
            onSubmit: (draft) => _save(selected, draft),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Sale Exchange'),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                icon: const AppIcon(AppIcons.refresh),
                onPressed: _provider.load,
              ),
              const SizedBox(width: 12),
            ],
          ),
          body: _InvoiceList(provider: _provider),
        );
      },
    );
  }
}

class _InvoiceList extends StatelessWidget {
  const _InvoiceList({required this.provider});

  final SaleExchangeProvider provider;

  @override
  Widget build(BuildContext context) {
    final invoices = provider.invoices;
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatCardRow(cards: [
            StatCard(
                title: 'Sale Invoices', subtitle: '${provider.invoiceCount}'),
            StatCard(
              title: 'Invoiced Value',
              subtitle: Fmt.money(
                  invoices.fold<double>(0, (a, i) => a + i.grandTotal)),
            ),
          ]),
          const SizedBox(height: 16),
          Expanded(
            child: SectionCard(
              title: 'Pick an invoice to exchange',
              subtitle: 'Opens the cart with its items — remove or add, then save',
              fillHeight: true,
              child: invoices.isEmpty
                  ? const EmptyState(
                      icon: AppIcons.swap_horiz_outlined,
                      title: 'No sale invoices yet')
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
                            onSelectChanged: (_) => provider.select(inv),
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
                              DataCell(IconButton(
                                tooltip: 'Exchange this invoice',
                                visualDensity: VisualDensity.compact,
                                icon: const AppIcon(
                                    AppIcons.swap_horiz_outlined,
                                    size: 18),
                                onPressed: () => provider.select(inv),
                              )),
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

// ───────────────────────────────────────────────────────────────────────────

class _ExchangeBuilder extends StatelessWidget {
  const _ExchangeBuilder({
    super.key,
    required this.invoice,
    required this.products,
    required this.saving,
    required this.onBack,
    required this.onSubmit,
  });

  final SaleInvoiceModel invoice;
  final List<ProductRef> products;
  final bool saving;
  final VoidCallback onBack;
  final Future<bool> Function(PosInvoiceDraft draft) onSubmit;

  double _stockFor(int? id) {
    if (id == null) return 0;
    for (final p in products) {
      if (p.id == id) return p.quantity;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final party = PosParty(
      id: invoice.customerId ?? 0,
      name: invoice.customerName.isEmpty ? 'Walk-in' : invoice.customerName,
    );

    return PosInvoiceBuilder(
      title: 'Sale Exchange',
      subtitle: 'Editing '
          '${invoice.invoiceNo.isEmpty ? "invoice #${invoice.id}" : invoice.invoiceNo}',
      icon: AppIcons.swap_horiz_outlined,
      accent: _accent,
      invoiceNo: invoice.invoiceNo.isEmpty
          ? '#${invoice.id}'
          : invoice.invoiceNo,
      partyHint: 'Customer',
      submitLabel: 'Save Exchange',
      saving: saving,
      showPrintReceiptToggle: true,
      showSecondaryPrice: false,
      showLineDiscountAmount: true,
      priceLabel: 'Sale',
      initialDate: invoice.date,
      onBack: onBack,
      defaultParty: party,
      parties: [party],
      products: [
        for (final p in products)
          PosProduct(
            id: p.id,
            name: p.name,
            barcode: p.barcode,
            unit: p.unit,
            price: p.salePrice,
            salePrice: p.salePrice,
            purchasePrice: p.purchasePrice,
            tax: p.tax,
            stock: p.quantity,
          ),
      ],
      initialLines: [
        for (var i = 0; i < invoice.items.length; i++)
          () {
            final it = invoice.items[i];
            return PosLineSeed(
              product: PosProduct(
                id: it.productId ?? -(i + 1),
                name: it.productName,
                barcode: it.barcode,
                unit: it.unit,
                price: it.salePrice,
                salePrice: it.salePrice,
                purchasePrice: it.purchasePrice,
                tax: it.tax,
                stock: _stockFor(it.productId),
              ),
              quantity: it.quantity,
              price: it.salePrice,
              discount: it.discount,
              discountFlat: it.discountFlat,
              tax: it.tax,
            );
          }(),
      ],
      onSubmit: onSubmit,
    );
  }
}
