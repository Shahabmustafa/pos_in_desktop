import 'package:flutter_test/flutter_test.dart';

import 'package:pos/features/sale_invoice/data/model/sale_invoice_model.dart';
import 'package:pos/shared/receipt/sale_receipt.dart';

void main() {
  test('builds a non-empty 80mm receipt PDF for a saved invoice', () async {
    final invoice = SaleInvoiceModel(
      invoiceNo: 'SI-000042',
      date: DateTime(2026, 9, 9, 14, 5),
      customerId: 2,
      customerName: 'Ali Traders',
      amountReceived: 500,
      items: const [
        SaleInvoiceItemModel(
          productId: 1,
          productName: 'Coca-Cola 1.5L',
          quantity: 3,
          salePrice: 120,
          discount: 10,
        ),
        SaleInvoiceItemModel(
          productId: 2,
          productName: 'Lays Masala 62g',
          quantity: 2,
          salePrice: 70,
        ),
      ],
    );

    final bytes = await buildSaleReceiptPdf(invoice);

    expect(bytes, isNotEmpty);
    // A PDF always starts with the "%PDF" magic bytes.
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('handles a walk-in invoice with no number and no items gracefully',
      () async {
    final invoice = SaleInvoiceModel(date: DateTime(2026, 1, 1));
    final bytes = await buildSaleReceiptPdf(invoice);
    expect(bytes, isNotEmpty);
  });
}
