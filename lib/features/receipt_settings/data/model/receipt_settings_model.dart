import 'package:flutter/foundation.dart';

/// Shop header + per-field show / hide flags for the 80mm thermal receipt.
///
/// Stored as a single row (`receipt_settings`, id = 1). Every receipt builder
/// reads [current] — a process-wide cached copy refreshed at startup and after
/// each save on the Receipt Settings screen. When the table has not loaded yet
/// (offline till, first run) the const defaults are used, which print the same
/// receipt the app shipped with.
class ReceiptSettingsModel {
  const ReceiptSettingsModel({
    this.businessName = 'POS',
    this.businessAddress = '',
    this.businessPhone = '',
    this.footerText = 'Thank you for shopping!',
    this.logo,
    this.showLogo = true,
    this.showInvoiceNo = true,
    this.showDate = true,
    this.showParty = true,
    this.showNotes = false,
    this.showItemDiscount = true,
    this.showDiscountTotal = true,
    this.showTaxTotal = true,
    this.showPaidBalance = true,
    this.showItemCount = true,
    this.showFooter = true,
  });

  /// Printed bold at the top. Blank → the line is skipped.
  final String businessName;

  /// Address line under the name. Blank → skipped.
  final String businessAddress;

  /// Phone line under the address. Blank → skipped.
  final String businessPhone;

  /// Line printed at the very bottom (e.g. "Thank you for shopping!"). Blank or
  /// [showFooter] off → skipped.
  final String footerText;

  /// Business logo image bytes (PNG / JPG), stored as `bytea`. `null` → no logo.
  /// Printed centred above the business name when [showLogo] is on.
  final Uint8List? logo;

  /// Whether to print [logo] (when one is set).
  final bool showLogo;

  /// Invoice / return number row in the header block.
  final bool showInvoiceNo;

  /// Date + time row in the header block.
  final bool showDate;

  /// Customer / Supplier name row in the header block.
  final bool showParty;

  /// Invoice notes row in the header block (only when the invoice has notes).
  final bool showNotes;

  /// The "discount -X" line under a product that had a line discount.
  final bool showItemDiscount;

  /// The "Discount" totals line (sum of all line discounts).
  final bool showDiscountTotal;

  /// The "Tax" totals line.
  final bool showTaxTotal;

  /// The "Paid" / "Balance" lines under the grand total (sale invoice only).
  final bool showPaidBalance;

  /// The "N item(s) - M unit(s)" line under the footer.
  final bool showItemCount;

  /// The [footerText] line.
  final bool showFooter;

  /// Cached copy the receipt builders read. Refreshed by
  /// [ReceiptSettingsProvider] and [preloadReceiptSettings].
  static ReceiptSettingsModel current = const ReceiptSettingsModel();

  factory ReceiptSettingsModel.fromMap(Map<String, dynamic> map) {
    bool flag(String key, {bool fallback = true}) =>
        (map[key] as bool?) ?? fallback;
    final rawLogo = map['logo'];
    return ReceiptSettingsModel(
      businessName: (map['business_name'] as String?) ?? 'POS',
      businessAddress: (map['business_address'] as String?) ?? '',
      businessPhone: (map['business_phone'] as String?) ?? '',
      footerText: (map['footer_text'] as String?) ?? 'Thank you for shopping!',
      logo: rawLogo is List<int> && rawLogo.isNotEmpty
          ? Uint8List.fromList(rawLogo)
          : null,
      showLogo: flag('show_logo'),
      showInvoiceNo: flag('show_invoice_no'),
      showDate: flag('show_date'),
      showParty: flag('show_party'),
      showNotes: flag('show_notes', fallback: false),
      showItemDiscount: flag('show_item_discount'),
      showDiscountTotal: flag('show_discount_total'),
      showTaxTotal: flag('show_tax_total'),
      showPaidBalance: flag('show_paid_balance'),
      showItemCount: flag('show_item_count'),
      showFooter: flag('show_footer'),
    );
  }

  /// The editable columns, keyed for `Sql.named` parameters. `id` and
  /// `updated_at` are handled by the datasource.
  Map<String, dynamic> toMap() => {
        'business_name': businessName,
        'business_address': businessAddress,
        'business_phone': businessPhone,
        'footer_text': footerText,
        'logo': logo,
        'show_logo': showLogo,
        'show_invoice_no': showInvoiceNo,
        'show_date': showDate,
        'show_party': showParty,
        'show_notes': showNotes,
        'show_item_discount': showItemDiscount,
        'show_discount_total': showDiscountTotal,
        'show_tax_total': showTaxTotal,
        'show_paid_balance': showPaidBalance,
        'show_item_count': showItemCount,
        'show_footer': showFooter,
      };

  /// Field-by-field equality, comparing [logo] by its bytes. Used for the
  /// "unsaved changes" check on the settings screen (a plain `==` / `mapEquals`
  /// would treat two equal logo byte lists as different).
  bool sameAs(ReceiptSettingsModel o) =>
      businessName == o.businessName &&
      businessAddress == o.businessAddress &&
      businessPhone == o.businessPhone &&
      footerText == o.footerText &&
      showLogo == o.showLogo &&
      showInvoiceNo == o.showInvoiceNo &&
      showDate == o.showDate &&
      showParty == o.showParty &&
      showNotes == o.showNotes &&
      showItemDiscount == o.showItemDiscount &&
      showDiscountTotal == o.showDiscountTotal &&
      showTaxTotal == o.showTaxTotal &&
      showPaidBalance == o.showPaidBalance &&
      showItemCount == o.showItemCount &&
      showFooter == o.showFooter &&
      listEquals(logo, o.logo);

  ReceiptSettingsModel copyWith({
    String? businessName,
    String? businessAddress,
    String? businessPhone,
    String? footerText,
    Uint8List? logo,
    bool clearLogo = false,
    bool? showLogo,
    bool? showInvoiceNo,
    bool? showDate,
    bool? showParty,
    bool? showNotes,
    bool? showItemDiscount,
    bool? showDiscountTotal,
    bool? showTaxTotal,
    bool? showPaidBalance,
    bool? showItemCount,
    bool? showFooter,
  }) {
    return ReceiptSettingsModel(
      businessName: businessName ?? this.businessName,
      businessAddress: businessAddress ?? this.businessAddress,
      businessPhone: businessPhone ?? this.businessPhone,
      footerText: footerText ?? this.footerText,
      logo: clearLogo ? null : (logo ?? this.logo),
      showLogo: showLogo ?? this.showLogo,
      showInvoiceNo: showInvoiceNo ?? this.showInvoiceNo,
      showDate: showDate ?? this.showDate,
      showParty: showParty ?? this.showParty,
      showNotes: showNotes ?? this.showNotes,
      showItemDiscount: showItemDiscount ?? this.showItemDiscount,
      showDiscountTotal: showDiscountTotal ?? this.showDiscountTotal,
      showTaxTotal: showTaxTotal ?? this.showTaxTotal,
      showPaidBalance: showPaidBalance ?? this.showPaidBalance,
      showItemCount: showItemCount ?? this.showItemCount,
      showFooter: showFooter ?? this.showFooter,
    );
  }
}
