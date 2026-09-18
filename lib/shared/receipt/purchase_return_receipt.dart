import 'dart:typed_data';

import '../../features/purchase_return/data/model/purchase_return_model.dart';
import 'sale_receipt.dart';

/// Builds an A4 invoice PDF for a saved [PurchaseReturnModel] — used to
/// reprint a return from the Reports screen (the original print-on-save flow
/// builds its own [ReceiptData] from the invoice + selection instead, see
/// `PurchaseReturnScreen._returnReceipt`).
Future<Uint8List> buildPurchaseReturnReceiptPdf(PurchaseReturnModel r) {
  return buildReceiptPdf(ReceiptData(
    docType: 'PURCHASE RETURN',
    invoiceNo: r.invoiceNo,
    date: r.returnDate,
    partyLabel: 'Supplier',
    partyName: r.companyName,
    extraInfo: [
      if (r.reference.trim().isNotEmpty) ('Against', r.reference.trim()),
    ],
    lines: [
      for (final it in r.items)
        ReceiptLine(
          name: it.productName,
          quantity: it.quantity,
          unitPrice: it.unitPrice,
          lineTotal: it.lineTotal,
          discountAmount: it.discountAmount,
        ),
    ],
    subtotal: r.subtotal,
    discountTotal: r.discountTotal,
    taxTotal: r.taxTotal,
    grandTotal: r.grandTotal,
    grandTotalLabel: 'RETURN TOTAL',
    notes: r.remarks,
  ));
}
