import 'dart:typed_data';

import '../../features/sale_return/data/model/sale_return_model.dart';
import 'sale_receipt.dart';

/// Builds an A4 invoice PDF for a saved [SaleReturnModel] — used to reprint a
/// return from the Reports screen (the original print-on-save flow builds its
/// own [ReceiptData] from the invoice + selection instead, see
/// `SaleReturnScreen._returnReceipt`).
Future<Uint8List> buildSaleReturnReceiptPdf(SaleReturnModel r) {
  return buildReceiptPdf(ReceiptData(
    docType: 'SALE RETURN',
    invoiceNo: r.invoiceNo,
    date: r.returnDate,
    partyLabel: 'Customer',
    partyName: r.customerName.isEmpty ? 'Walk-in' : r.customerName,
    lines: [
      for (final it in r.items)
        ReceiptLine(
          name: it.productName,
          quantity: it.quantity,
          unitPrice: it.salePrice,
          lineTotal: it.lineTotal,
          discountAmount: it.discountAmount,
          unit: it.unit,
        ),
    ],
    subtotal: r.subtotal,
    discountTotal: r.discountTotal,
    taxTotal: r.taxTotal,
    grandTotal: r.grandTotal,
    grandTotalLabel: 'REFUND TOTAL',
    notes: r.notes,
    extraTotals: [
      ReceiptTotal('Paid', r.amountPaid),
      if (r.balanceDue.abs() > 0.009)
        ReceiptTotal('Balance', r.balanceDue, bold: true),
    ],
  ));
}
