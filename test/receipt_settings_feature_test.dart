import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos/features/receipt_settings/data/datasource/receipt_settings_datasource.dart';
import 'package:pos/features/receipt_settings/data/model/receipt_settings_model.dart';
import 'package:pos/features/receipt_settings/data/repository/receipt_settings_repository.dart';
import 'package:pos/features/receipt_settings/presentation/provider/receipt_settings_provider.dart';
import 'package:pos/features/receipt_settings/presentation/screen/receipt_settings_screen.dart';
import 'package:pos/features/sale_invoice/data/model/sale_invoice_model.dart';
import 'package:pos/shared/receipt/sale_receipt.dart';

class _FakeDataSource extends ReceiptSettingsDataSource {
  _FakeDataSource(this.stored);

  ReceiptSettingsModel stored;

  @override
  Future<void> ensureSchema() async {}

  @override
  Future<ReceiptSettingsModel> fetch() async => stored;

  @override
  Future<ReceiptSettingsModel> save(ReceiptSettingsModel s) async {
    stored = s;
    return s;
  }
}

void main() {
  setUp(() => ReceiptSettingsModel.current = const ReceiptSettingsModel());

  test('model survives a fromMap / toMap round trip', () {
    final model = ReceiptSettingsModel(
      businessName: 'Ahmed Store',
      businessAddress: 'Main Bazaar, Lahore',
      businessPhone: '0300-1234567',
      footerText: 'Shukriya!',
      logo: Uint8List.fromList([1, 2, 3, 4]),
      showLogo: false,
      showInvoiceNo: false,
      showTaxTotal: false,
      showNotes: true,
    );
    final back = ReceiptSettingsModel.fromMap(model.toMap());
    expect(back.businessName, 'Ahmed Store');
    expect(back.businessPhone, '0300-1234567');
    expect(back.logo, [1, 2, 3, 4]);
    expect(back.showLogo, isFalse);
    expect(back.showInvoiceNo, isFalse);
    expect(back.showTaxTotal, isFalse);
    expect(back.showNotes, isTrue);
    expect(back.showDate, isTrue);
  });

  test('sameAs compares the logo by its bytes', () {
    final a = ReceiptSettingsModel(logo: Uint8List.fromList([9, 8, 7]));
    final b = ReceiptSettingsModel(logo: Uint8List.fromList([9, 8, 7]));
    final c = ReceiptSettingsModel(logo: Uint8List.fromList([9, 8, 6]));
    expect(a.sameAs(b), isTrue);
    expect(a.sameAs(c), isFalse);
    expect(a.sameAs(const ReceiptSettingsModel()), isFalse);
  });

  test('save persists and refreshes the cached current settings', () async {
    final ds = _FakeDataSource(const ReceiptSettingsModel());
    final provider =
        ReceiptSettingsProvider(ReceiptSettingsRepository(ds));
    await provider.load();

    final ok = await provider.save(
      provider.settings.copyWith(businessName: 'Bilal Traders', showFooter: false),
    );

    expect(ok, isTrue);
    expect(ds.stored.businessName, 'Bilal Traders');
    expect(ReceiptSettingsModel.current.businessName, 'Bilal Traders');
    expect(ReceiptSettingsModel.current.showFooter, isFalse);
  });

  test('receipt builder honours the cached toggles', () async {
    final invoice = SaleInvoiceModel(
      invoiceNo: 'SI-000042',
      date: DateTime(2026, 9, 9, 14, 5),
      customerName: 'Ali Traders',
      amountReceived: 300,
      items: const [
        SaleInvoiceItemModel(
            productName: 'Coca-Cola 1.5L', quantity: 3, salePrice: 120, tax: 5),
      ],
    );

    ReceiptSettingsModel.current = const ReceiptSettingsModel();
    final full = await buildSaleReceiptPdf(invoice);

    ReceiptSettingsModel.current = const ReceiptSettingsModel(
      businessName: 'X',
      showParty: false,
      showTaxTotal: false,
      showPaidBalance: false,
      showItemCount: false,
      showFooter: false,
    );
    final trimmed = await buildSaleReceiptPdf(invoice);

    // Both are valid PDFs; the trimmed one carries fewer glyphs.
    expect(String.fromCharCodes(full.take(4)), '%PDF');
    expect(String.fromCharCodes(trimmed.take(4)), '%PDF');
    expect(trimmed.length, lessThan(full.length));
  });

  testWidgets('screen shows the header fields, toggles and a live preview',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final provider = ReceiptSettingsProvider(
      ReceiptSettingsRepository(
        _FakeDataSource(const ReceiptSettingsModel(businessName: 'Ahmed Store')),
      ),
    );
    await provider.load();

    await tester.pumpWidget(
      MaterialApp(home: ReceiptSettingsScreen(provider: provider)),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Receipt Settings'), findsOneWidget);
    expect(find.text('Business header'), findsOneWidget);
    expect(find.text('Show on receipt'), findsOneWidget);
    expect(find.text('Live preview'), findsOneWidget);
    expect(find.text('Upload logo'), findsOneWidget);
    // The typed business name appears both in the field and the preview.
    expect(find.text('Ahmed Store'), findsWidgets);
    expect(find.text('Save changes'), findsOneWidget);
    // Nothing edited yet → no "Discard changes" button.
    expect(find.text('Discard changes'), findsNothing);

    // Editing the footer field marks the form dirty.
    await tester.enterText(find.widgetWithText(TextField, 'Footer line'), 'Bye');
    await tester.pumpAndSettle();
    expect(find.text('Discard changes'), findsOneWidget);
  });
}
