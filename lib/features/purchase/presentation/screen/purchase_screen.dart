import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pos/shared/app_icon.dart';

import '../../../../shared/customer_payment_dialog.dart';
import '../../../../shared/feature_ui.dart';
import '../../../../shared/pos_invoice_builder.dart';
import '../../../../shared/receipt/receipt_printer.dart';
import '../../../../shared/receipt/sale_receipt.dart';
import '../../data/model/purchase_model.dart';
import '../provider/purchase_provider.dart';

/// Purchase Invoice module — a POS-style builder: search products on the left,
/// build the supplier invoice (company, number, date) in the cart on the right.
class PurchaseScreen extends StatefulWidget {
  const PurchaseScreen({super.key, this.provider});

  static const String routeName = '/purchase';

  final PurchaseProvider? provider;

  @override
  State<PurchaseScreen> createState() => _PurchaseScreenState();
}

class _PurchaseScreenState extends State<PurchaseScreen> {
  late final PurchaseProvider _provider =
      widget.provider ?? PurchaseProvider();

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
        PurchaseItemModel(
          productId: l.product.id,
          productName: l.product.name,
          barcode: l.product.barcode,
          unit: l.product.unit,
          quantity: l.quantity,
          purchasePrice: l.price,
          salePrice: l.salePrice,
          discount: l.discount,
          tax: l.tax,
        ),
    ];
    final grandTotal = items.fold<double>(0, (a, i) => a + i.lineTotal);

    // For a real supplier, confirm how much is paid now; the rest is left on
    // the company's balance. The dialog shows the company's static opening
    // balance (not the live running payable — see PurchaseDataSource.
    // fetchCompanies for that figure, still used elsewhere e.g. Pay Company).
    final companyId = draft.party?.id;
    double amountPaid = grandTotal;
    if (companyId != null) {
      double previousBalance = 0;
      for (final c in _provider.companies) {
        if (c.id == companyId) {
          previousBalance = c.openingBalance;
          break;
        }
      }
      final result = await showCustomerPaymentDialog(
        context,
        customerName: draft.party!.name,
        previousBalance: previousBalance,
        totalAmount: grandTotal,
        totalLabel: 'Total purchase amount',
        actionLabel: 'Save Invoice',
        partyLabel: 'Company',
        icon: AppIcons.business_outlined,
        accent: const Color(0xFF2196F3),
      );
      if (result == null) return false; // cancelled
      amountPaid = result.payAmount;
    }

    final model = PurchaseModel(
      date: draft.date,
      companyId: companyId,
      companyName: draft.party?.name ?? '',
      notes: draft.notes,
      amountPaid: amountPaid,
      items: items,
    );
    final ok = await _provider.save(model);
    if (!mounted) return ok;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Purchase invoice saved')),
      );
      final saved = _provider.lastSaved;
      if (saved != null && draft.printReceipt) {
        unawaited(ReceiptPrinter.instance.printReceipt(
          context,
          buildReceiptPdf(_purchaseReceipt(saved)),
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

  ReceiptData _purchaseReceipt(PurchaseModel p) => ReceiptData(
        docType: 'PURCHASE INVOICE',
        invoiceNo: p.invoiceNo.isNotEmpty ? p.invoiceNo : '#${p.id ?? ''}',
        date: p.date,
        partyLabel: 'Supplier',
        partyName: p.companyName,
        lines: [
          for (final it in p.items)
            ReceiptLine(
              name: it.productName,
              quantity: it.quantity,
              unitPrice: it.purchasePrice,
              lineTotal: it.lineTotal,
              discountAmount: it.discountAmount,
            ),
        ],
        subtotal: p.subtotal,
        discountTotal: p.discountTotal,
        taxTotal: p.taxTotal,
        grandTotal: p.grandTotal,
        extraTotals: [
          ReceiptTotal('Paid', p.amountPaid),
          if (p.balanceDue.abs() > 0.009)
            ReceiptTotal('Balance', p.balanceDue, bold: true),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        if (_provider.loading) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (_provider.error != null && _provider.items.isEmpty &&
            _provider.companies.isEmpty) {
          return Scaffold(
            body: ErrorState(
                message: _provider.error!, onRetry: _provider.load),
          );
        }
        return PosInvoiceBuilder(
          title: 'Purchase Invoice',
          subtitle: 'Record a new supplier bill',
          icon: AppIcons.shopping_cart_outlined,
          accent: const Color(0xFF2196F3),
          invoiceNo: _provider.nextNumber(),
          partyHint: 'Company (supplier)',
          submitLabel: 'Save Invoice',
          saving: _provider.saving,
          showPrintReceiptToggle: true,
          parties: [
            for (final c in _provider.companies)
              PosParty(id: c.id, name: c.name),
          ],
          products: [
            for (final p in _provider.products)
              PosProduct(
                id: p.id,
                name: p.name,
                barcode: p.barcode,
                unit: p.unit,
                price: p.purchasePrice,
                salePrice: p.salePrice,
                stock: p.quantity,
              ),
          ],
          onSubmit: _save,
        );
      },
    );
  }
}
