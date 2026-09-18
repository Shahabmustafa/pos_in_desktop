import 'dart:typed_data';

import '../../features/purchase/data/model/purchase_model.dart';
import 'sale_receipt.dart';

/// Builds an A4 invoice PDF for a saved [PurchaseModel].
Future<Uint8List> buildPurchaseReceiptPdf(PurchaseModel p) {
  return buildReceiptPdf(ReceiptData(
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
          unit: it.unit,
        ),
    ],
    subtotal: p.subtotal,
    discountTotal: p.discountTotal,
    taxTotal: p.taxTotal,
    grandTotal: p.grandTotal,
    notes: p.notes,
    extraTotals: [
      ReceiptTotal('Paid', p.amountPaid),
      if (p.balanceDue.abs() > 0.009)
        ReceiptTotal('Balance', p.balanceDue, bold: true),
    ],
  ));
}
