import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pos/shared/app_icon.dart';

import '../../../../config/theme/app_theme.dart';
import '../../../../shared/feature_ui.dart';
import '../../../../shared/pos_invoice_builder.dart';
import '../../../../shared/receipt/receipt_printer.dart';
import '../../../login/presentation/access_scope.dart';
import '../../data/model/held_sale_invoice_model.dart';
import '../../data/model/sale_invoice_model.dart';
import '../provider/sale_invoice_provider.dart';

/// Sale Invoice module — a POS-style builder: search products on the left,
/// build the customer invoice (customer, number, date) in the cart on the
/// right. Saving reduces stock.
class SaleInvoiceScreen extends StatefulWidget {
  const SaleInvoiceScreen({super.key, this.provider});

  static const String routeName = '/sale_invoice';

  final SaleInvoiceProvider? provider;

  @override
  State<SaleInvoiceScreen> createState() => _SaleInvoiceScreenState();
}

class _SaleInvoiceScreenState extends State<SaleInvoiceScreen> {
  late final SaleInvoiceProvider _provider =
      widget.provider ?? SaleInvoiceProvider();

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

  Future<bool> _save(PosInvoiceDraft draft) async {
    final items = [
      for (final l in draft.lines)
        SaleInvoiceItemModel(
          productId: l.product.id,
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
    final grandTotal = items.fold<double>(0, (a, i) => a + i.lineTotal);

    // Walk-in (or no customer) sales are paid in full at the counter; a real
    // customer's sale goes straight to their credit — collect it later from
    // Receive Payment.
    final customerId = draft.party?.id;
    final walkInId = _provider.walkInCustomer?.id;
    final amountReceived =
        (customerId != null && customerId != walkInId) ? 0.0 : grandTotal;

    final model = SaleInvoiceModel(
      date: draft.date,
      customerId: customerId,
      customerName: draft.party?.name ?? '',
      notes: draft.notes,
      amountReceived: amountReceived,
      bankHeadId: draft.bankId,
      items: items,
    );
    final ok = await _provider.save(model);
    if (!mounted) return ok;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sale invoice saved')),
      );
      // Print the invoice on the printer (never blocks the sale) —
      // only when the operator left the "Print receipt" checkbox ticked.
      final saved = _provider.lastSaved;
      if (saved != null && draft.printReceipt) {
        unawaited(ReceiptPrinter.instance.printSaleInvoice(
          context,
          saved,
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
    return ok;
  }

  /// Parks the current cart as a held invoice.
  Future<bool> _hold(PosInvoiceDraft draft) async {
    final walkInId = _provider.walkInCustomer?.id;
    final customerId = draft.party?.id;
    final held = HeldSaleInvoiceModel(
      customerId: (customerId == null || customerId == walkInId)
          ? null
          : customerId,
      customerName: draft.party?.name ?? '',
      notes: draft.notes,
      bankHeadId: draft.bankId,
      date: draft.date,
      heldBy: AccessScope.of(context).user?.username ?? '',
      lines: [
        for (final l in draft.lines)
          HeldSaleLineModel(
            productId: l.product.id,
            productName: l.product.name,
            quantity: l.quantity,
            price: l.price,
            discount: l.discount,
            discountFlat: l.discountFlat,
            tax: l.tax,
          ),
      ],
    );
    final ok = await _provider.hold(held);
    if (!mounted) return ok;
    if (!ok && _provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_provider.error!)),
      );
    }
    return ok;
  }

  List<HeldOrder> _heldOrders() => [
        for (final h in _provider.heldInvoices)
          if (h.id != null)
            HeldOrder(
              id: h.id!,
              title: h.title,
              itemCount: h.itemCount,
              total: h.grandTotal,
              heldAt: h.heldAt,
              heldBy: h.heldBy,
              partyId: h.customerId,
              date: h.date,
              notes: h.notes,
              bankId: h.bankHeadId,
              lines: [
                for (final l in h.lines)
                  HeldOrderLine(
                    productId: l.productId,
                    quantity: l.quantity,
                    price: l.price,
                    discount: l.discount,
                    discountFlat: l.discountFlat,
                    tax: l.tax,
                  ),
              ],
            ),
      ];

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        if (_provider.loading) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (_provider.error != null &&
            _provider.items.isEmpty &&
            _provider.customers.isEmpty) {
          return Scaffold(
            body: ErrorState(
                message: _provider.error!, onRetry: _provider.load),
          );
        }
        return PosInvoiceBuilder(
          title: 'Sale Invoice',
          subtitle: 'Bill a customer',
          icon: AppIcons.point_of_sale_outlined,
          accent: AppTheme.brand,
          invoiceNo: _provider.nextNumber(),
          partyHint: 'Customer',
          submitLabel: 'Save Invoice',
          saving: _provider.saving,
          showSecondaryPrice: false,
          showLineDiscountAmount: true,
          showPrintReceiptToggle: true,
          priceLabel: 'Sale',
          defaultParty: _provider.walkInCustomer == null
              ? null
              : PosParty(
                  id: _provider.walkInCustomer!.id,
                  name: _provider.walkInCustomer!.name,
                ),
          parties: [
            for (final c in _provider.customers)
              PosParty(id: c.id, name: c.name),
          ],
          banks: [
            for (final b in _provider.banks)
              PosBankOption(id: b.id!, name: b.title),
          ],
          products: [
            for (final p in _provider.products)
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
          heldOrders: _heldOrders(),
          onHoldOrder: _hold,
          onRemoveHeldOrder: _provider.deleteHeld,
          onSubmit: _save,
        );
      },
    );
  }
}
