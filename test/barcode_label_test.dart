import 'package:flutter_test/flutter_test.dart';

import 'package:pos/shared/receipt/barcode_label.dart';

void main() {
  test('builds a Code 128 barcode label PDF for a product', () async {
    final bytes = await buildBarcodeLabelPdf(
      barcode: 'ABC-12345',
      productName: 'Coca-Cola 1.5L',
      priceLabel: 'Rs 120',
    );

    expect(bytes, isNotEmpty);
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('handles a product with no barcode / no price gracefully', () async {
    final bytes = await buildBarcodeLabelPdf(barcode: '', productName: 'x');
    expect(bytes, isNotEmpty);
  });
}
