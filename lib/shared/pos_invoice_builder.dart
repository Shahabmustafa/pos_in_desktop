import 'package:flutter/material.dart';
import 'package:pos/shared/app_icon.dart';
import 'package:flutter/services.dart';

import '../config/format.dart';
import 'searchable_dropdown.dart';

/// A product that can be added onto a POS-style invoice line.
class PosProduct {
  const PosProduct({
    required this.id,
    required this.name,
    this.barcode = '',
    this.unit = 'pcs',
    this.price = 0,
    this.salePrice = 0,
    this.purchasePrice = 0,
    this.tax = 0,
    this.stock = 0,
  });

  final int id;
  final String name;
  final String barcode;
  final String unit;

  /// On-hand quantity in `stock_item`. Shown in the product list so the
  /// operator can see availability while building the invoice.
  final double stock;

  /// Default unit price used when the product is first added to a line
  /// (the purchase price for purchase / return invoices, the sale price for
  /// sale invoices / returns).
  final double price;

  /// The product's sale price — shown for reference alongside [price].
  final double salePrice;

  /// The product's cost (purchase) price. Carried onto a sale line so reports
  /// can work out per-line / per-invoice profit.
  final double purchasePrice;

  /// Default tax percentage for a new line.
  final double tax;

  @override
  bool operator ==(Object other) => other is PosProduct && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => name;
}

/// A supplier / company option for the invoice's party picker.
class PosParty {
  const PosParty({required this.id, required this.name});

  final int id;
  final String name;

  @override
  bool operator ==(Object other) => other is PosParty && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => name;
}

/// A bank account option for the optional "Bank" picker in the cart header.
/// When set on save, the money taken / paid is also posted as a bank entry.
class PosBankOption {
  const PosBankOption({required this.id, required this.name});

  final int id;
  final String name;

  @override
  bool operator ==(Object other) => other is PosBankOption && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => name;
}

/// One line the user is building, wired to its text controllers.
class PosLine {
  PosLine({
    required this.product,
    double quantity = 1,
    double? price,
    double? salePrice,
    double discount = 0,
    double discountFlat = 0,
    double? tax,
    required VoidCallback onChanged,
  })  : qtyCtrl = TextEditingController(text: _fmt(quantity)),
        priceCtrl = TextEditingController(text: _fmt(price ?? product.price)),
        salePriceCtrl =
            TextEditingController(text: _fmt(salePrice ?? product.salePrice)),
        discCtrl = TextEditingController(text: _fmt(discount)),
        discAmtCtrl = TextEditingController(text: _fmt(discountFlat)),
        taxCtrl = TextEditingController(text: _fmt(tax ?? product.tax)) {
    for (final c in [qtyCtrl, priceCtrl, salePriceCtrl, discCtrl, discAmtCtrl,
        taxCtrl]) {
      c.addListener(onChanged);
    }
  }

  final PosProduct product;
  final TextEditingController qtyCtrl;
  final TextEditingController priceCtrl;
  final TextEditingController salePriceCtrl;
  final TextEditingController discCtrl;
  final TextEditingController discAmtCtrl;
  final TextEditingController taxCtrl;

  double get quantity => double.tryParse(qtyCtrl.text.trim()) ?? 0;
  double get price => double.tryParse(priceCtrl.text.trim()) ?? 0;
  double get salePrice => double.tryParse(salePriceCtrl.text.trim()) ?? 0;

  /// Per-line discount percentage.
  double get discount => double.tryParse(discCtrl.text.trim()) ?? 0;

  /// Per-line flat (rupee) discount, on top of [discount].
  double get discountFlat => double.tryParse(discAmtCtrl.text.trim()) ?? 0;

  double get tax => double.tryParse(taxCtrl.text.trim()) ?? 0;

  double get gross => quantity * price;
  double get discountAmount =>
      (gross * discount / 100 + discountFlat).clamp(0, gross).toDouble();
  double get taxAmount => (gross - discountAmount) * tax / 100;
  double get lineTotal => gross - discountAmount + taxAmount;

  void addQuantity(double delta) {
    final q = quantity + delta;
    qtyCtrl.text = _fmt(q < 0 ? 0 : q);
  }

  void dispose() {
    qtyCtrl.dispose();
    priceCtrl.dispose();
    salePriceCtrl.dispose();
    discCtrl.dispose();
    discAmtCtrl.dispose();
    taxCtrl.dispose();
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

/// A cart line to pre-load into the builder (used by Sale Exchange, which opens
/// an existing invoice's items in the cart).
class PosLineSeed {
  const PosLineSeed({
    required this.product,
    this.quantity = 1,
    this.price,
    this.salePrice,
    this.discount = 0,
    this.discountFlat = 0,
    this.tax,
  });

  final PosProduct product;
  final double quantity;
  final double? price;
  final double? salePrice;
  final double discount;
  final double discountFlat;
  final double? tax;
}

/// A parked ("held") order shown in the builder's Resume list. The caller
/// stores these however it likes; the builder only reads them to rebuild the
/// cart.
class HeldOrder {
  const HeldOrder({
    required this.id,
    required this.title,
    required this.itemCount,
    required this.total,
    required this.heldAt,
    required this.partyId,
    required this.date,
    required this.notes,
    required this.bankId,
    required this.lines,
    this.heldBy = '',
  });

  final int id;

  /// Party name / "Walk-in" — shown in the list.
  final String title;
  final int itemCount;
  final double total;
  final DateTime heldAt;

  /// Username of whoever held it (optional, shown in the list).
  final String heldBy;

  /// Cart state to restore on resume.
  final int? partyId;
  final DateTime date;
  final String notes;
  final int? bankId;
  final List<HeldOrderLine> lines;
}

/// One cart line inside a [HeldOrder].
class HeldOrderLine {
  const HeldOrderLine({
    required this.productId,
    this.quantity = 1,
    this.price,
    this.salePrice,
    this.discount = 0,
    this.discountFlat = 0,
    this.tax,
  });

  final int productId;
  final double quantity;
  final double? price;
  final double? salePrice;
  final double discount;
  final double discountFlat;
  final double? tax;
}

/// What [PosInvoiceBuilder] hands back when the user saves.
class PosInvoiceDraft {
  PosInvoiceDraft({
    required this.party,
    required this.date,
    required this.notes,
    required this.lines,
    this.bankId,
    this.printReceipt = true,
  });

  final PosParty? party;
  final DateTime date;
  final String notes;
  final List<PosLine> lines;

  /// Selected bank account id, or `null` for a plain cash sale.
  final int? bankId;

  /// Whether the caller should print a receipt after saving. Only meaningful
  /// when [PosInvoiceBuilder.showPrintReceiptToggle] is on; otherwise `true`.
  final bool printReceipt;
}

/// A two-pane POS builder: a searchable product list on the left, the running
/// cart (with a supplier company, invoice number and date) on the right.
///
/// It owns all cart state. On save it calls [onSubmit]; if that returns `true`
/// the cart is cleared for the next invoice.
class PosInvoiceBuilder extends StatefulWidget {
  const PosInvoiceBuilder({
    super.key,
    required this.title,
    required this.subtitle,
    required this.invoiceNo,
    required this.parties,
    required this.products,
    required this.onSubmit,
    this.accent = const Color(0xFF2196F3),
    this.icon = AppIcons.shopping_cart_outlined,
    this.partyHint = 'Company (supplier)',
    this.submitLabel = 'Save Invoice',
    this.saving = false,
    this.initialDate,
    this.defaultParty,
    this.priceLabel = 'Purch.',
    this.showSecondaryPrice = true,
    this.showLineDiscountAmount = false,
    this.banks = const [],
    this.bankHint = 'Bank (optional)',
    this.initialLines = const [],
    this.onBack,
    this.showPrintReceiptToggle = false,
    this.printReceiptDefault = true,
    this.heldOrders = const [],
    this.onHoldOrder,
    this.onRemoveHeldOrder,
  });

  final String title;
  final String subtitle;

  /// Displayed (read-only) next invoice number.
  final String invoiceNo;

  final List<PosParty> parties;
  final List<PosProduct> products;
  final Color accent;
  final String icon;
  final String partyHint;
  final String submitLabel;
  final bool saving;
  final DateTime? initialDate;

  /// Pre-selected party (e.g. a walk-in customer) so a quick sale needs no
  /// picking. Must be one of [parties] to show as selected.
  final PosParty? defaultParty;

  /// Header label for the editable unit-price cart column.
  final String priceLabel;

  /// When `true` the cart shows a second editable "Sale" price column (used by
  /// purchase invoices, where the operator also captures the selling price).
  final bool showSecondaryPrice;

  /// When `true` each cart line gets a second discount field — a flat (rupee)
  /// amount alongside the discount percentage.
  final bool showLineDiscountAmount;

  /// Optional bank accounts. When non-empty the cart header shows a "Bank"
  /// picker; the chosen id rides back on [PosInvoiceDraft.bankId].
  final List<PosBankOption> banks;
  final String bankHint;

  /// Cart lines to start with (Sale Exchange opens an invoice's items here).
  final List<PosLineSeed> initialLines;

  /// When set, a back arrow is shown in the app bar.
  final VoidCallback? onBack;

  /// When `true` the summary shows a "Print receipt" checkbox; its state rides
  /// back on [PosInvoiceDraft.printReceipt] so the caller can skip printing.
  final bool showPrintReceiptToggle;

  /// Initial state of the "Print receipt" checkbox.
  final bool printReceiptDefault;

  /// Parked carts the operator can resume. When non-empty a "Held (N)" button
  /// appears in the app bar.
  final List<HeldOrder> heldOrders;

  /// When set, a "Hold" button appears next to Clear. It receives the current
  /// cart as a draft; return `true` to park it and clear the cart.
  final Future<bool> Function(PosInvoiceDraft draft)? onHoldOrder;

  /// Called with a held order's id once its lines have been loaded back into the
  /// cart — the caller should delete it from its store.
  final void Function(int heldOrderId)? onRemoveHeldOrder;

  /// Returns `true` when the invoice was saved (builder then resets).
  final Future<bool> Function(PosInvoiceDraft draft) onSubmit;

  @override
  State<PosInvoiceBuilder> createState() => _PosInvoiceBuilderState();
}

class _PosInvoiceBuilderState extends State<PosInvoiceBuilder> {
  final _searchCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _notesCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  final _cartScrollCtrl = ScrollController();

  late DateTime _date = widget.initialDate ?? DateTime.now();
  late PosParty? _party = widget.defaultParty;
  int? _bankId;
  late bool _printReceipt = widget.printReceiptDefault;
  final List<PosLine> _lines = [];
  int _highlightId = -1;
  int _prevLineCount = 0;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() => setState(() => _highlightId = -1));
    for (final seed in widget.initialLines) {
      _lines.add(PosLine(
        product: seed.product,
        quantity: seed.quantity,
        price: seed.price,
        salePrice: seed.salePrice,
        discount: seed.discount,
        discountFlat: seed.discountFlat,
        tax: seed.tax,
        onChanged: _recalc,
      ));
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _qtyCtrl.dispose();
    _notesCtrl.dispose();
    _searchFocus.dispose();
    _cartScrollCtrl.dispose();
    for (final l in _lines) {
      l.dispose();
    }
    super.dispose();
  }

  // ── Derived ────────────────────────────────────────────────────────
  List<PosProduct> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return widget.products;
    return widget.products
        .where((p) =>
            p.name.toLowerCase().contains(q) ||
            p.barcode.toLowerCase().contains(q))
        .toList();
  }

  double get _subtotal => _lines.fold(0, (a, l) => a + l.gross);
  double get _discountTotal => _lines.fold(0, (a, l) => a + l.discountAmount);
  double get _taxTotal => _lines.fold(0, (a, l) => a + l.taxAmount);
  double get _grandTotal => _lines.fold(0, (a, l) => a + l.lineTotal);
  double get _totalUnits => _lines.fold(0, (a, l) => a + l.quantity);

  void _recalc() => setState(() {});

  // ── Actions ────────────────────────────────────────────────────────
  void _addProduct(PosProduct p) {
    final qty = double.tryParse(_qtyCtrl.text.trim()) ?? 1;
    PosLine? existing;
    for (final l in _lines) {
      if (l.product.id == p.id) {
        existing = l;
        break;
      }
    }
    setState(() {
      if (existing != null) {
        existing.addQuantity(qty <= 0 ? 1 : qty);
      } else {
        _lines.add(PosLine(
          product: p,
          quantity: qty <= 0 ? 1 : qty,
          onChanged: _recalc,
        ));
      }
      _qtyCtrl.text = '1';
      _searchCtrl.clear();
      _highlightId = -1;
    });
    _searchFocus.requestFocus();
  }

  void _onSearchSubmitted(String value) {
    final q = value.trim().toLowerCase();
    if (q.isEmpty) return;
    // Exact barcode / name match first (barcode-scanner friendly).
    for (final p in widget.products) {
      if (p.barcode.toLowerCase() == q || p.name.toLowerCase() == q) {
        _addProduct(p);
        return;
      }
    }
    final list = _filtered;
    if (list.length == 1) {
      _addProduct(list.first);
    } else if (list.isNotEmpty) {
      setState(() => _highlightId = list.first.id);
    }
  }

  void _removeLine(PosLine line) {
    setState(() {
      _lines.remove(line);
      line.dispose();
    });
  }

  void _clearCart() {
    setState(() {
      for (final l in _lines) {
        l.dispose();
      }
      _lines.clear();
    });
  }

  Future<void> _confirmClear() async {
    if (_lines.isEmpty) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear invoice?'),
        content: const Text('All lines will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear')),
        ],
      ),
    );
    if (yes == true) _clearCart();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _submit() async {
    if (_party == null) {
      _snack('Select ${widget.partyHint} first');
      return;
    }
    if (_lines.isEmpty) {
      _snack('Add at least one product');
      return;
    }
    if (_lines.any((l) => l.quantity <= 0)) {
      _snack('Every line needs a quantity above zero');
      return;
    }
    final ok = await widget.onSubmit(PosInvoiceDraft(
      party: _party,
      date: _date,
      notes: _notesCtrl.text.trim(),
      lines: List.of(_lines),
      bankId: _bankId,
      printReceipt: _printReceipt,
    ));
    if (!mounted || !ok) return;
    setState(() {
      for (final l in _lines) {
        l.dispose();
      }
      _lines.clear();
      _notesCtrl.clear();
      _date = DateTime.now();
      _bankId = null;
    });
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg)));

  PosProduct? _productById(int id) {
    for (final p in widget.products) {
      if (p.id == id) return p;
    }
    return null;
  }

  PosParty? _partyById(int? id) {
    if (id == null) return null;
    for (final p in widget.parties) {
      if (p.id == id) return p;
    }
    return null;
  }

  // ── Hold / resume ──────────────────────────────────────────────────
  Future<void> _hold() async {
    final onHold = widget.onHoldOrder;
    if (onHold == null) return;
    if (_lines.isEmpty) {
      _snack('Add at least one product before holding');
      return;
    }
    if (_lines.any((l) => l.quantity <= 0)) {
      _snack('Every line needs a quantity above zero');
      return;
    }
    final ok = await onHold(PosInvoiceDraft(
      party: _party,
      date: _date,
      notes: _notesCtrl.text.trim(),
      lines: List.of(_lines),
      bankId: _bankId,
      printReceipt: _printReceipt,
    ));
    if (!mounted || !ok) return;
    setState(() {
      for (final l in _lines) {
        l.dispose();
      }
      _lines.clear();
      _notesCtrl.clear();
      _date = DateTime.now();
      _bankId = null;
      _party = widget.defaultParty;
    });
    _snack('Invoice held');
  }

  Future<void> _openHeldOrders() async {
    final picked = await showDialog<HeldOrder>(
      context: context,
      builder: (_) => _HeldOrdersDialog(
        orders: widget.heldOrders,
        accent: widget.accent,
        onDelete: (o) => widget.onRemoveHeldOrder?.call(o.id),
      ),
    );
    if (picked == null || !mounted) return;

    if (_lines.isNotEmpty) {
      final replace = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Replace current cart?'),
          content: const Text(
              'The lines in the cart will be cleared and the held invoice '
              'loaded in their place.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Replace')),
          ],
        ),
      );
      if (replace != true || !mounted) return;
    }
    _resume(picked);
  }

  void _resume(HeldOrder o) {
    var missing = 0;
    setState(() {
      for (final l in _lines) {
        l.dispose();
      }
      _lines.clear();
      for (final hl in o.lines) {
        final product = _productById(hl.productId);
        if (product == null) {
          missing++;
          continue;
        }
        _lines.add(PosLine(
          product: product,
          quantity: hl.quantity,
          price: hl.price,
          salePrice: hl.salePrice,
          discount: hl.discount,
          discountFlat: hl.discountFlat,
          tax: hl.tax,
          onChanged: _recalc,
        ));
      }
      _party = _partyById(o.partyId) ?? widget.defaultParty;
      _date = o.date;
      _notesCtrl.text = o.notes;
      _bankId = o.bankId;
    });
    widget.onRemoveHeldOrder?.call(o.id);
    if (missing > 0) {
      _snack('$missing item(s) skipped — no longer in the product list');
    }
  }

  // ── Build ──────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_lines.length > _prevLineCount) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_cartScrollCtrl.hasClients) {
          _cartScrollCtrl.animateTo(
            _cartScrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    }
    _prevLineCount = _lines.length;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: widget.onBack == null ? 16 : 0,
        leading: widget.onBack == null
            ? null
            : IconButton(
                tooltip: 'Back',
                icon: const AppIcon(AppIcons.chevron_left),
                onPressed: widget.onBack,
              ),
        title: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: widget.accent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: AppIcon(widget.icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
              Text(widget.subtitle,
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.outline)),
            ],
          ),
        ]),
        actions: [
          if (widget.heldOrders.isNotEmpty) ...[
            InkWell(
              onTap: _openHeldOrders,
              borderRadius: BorderRadius.circular(8),
              child: _HeaderChip(
                icon: AppIcons.history,
                label: 'Held ${widget.heldOrders.length}',
                accent: const Color(0xFFC77700),
              ),
            ),
            const SizedBox(width: 8),
          ],
          _HeaderChip(
            icon: AppIcons.receipt_long_outlined,
            label: widget.invoiceNo,
            accent: widget.accent,
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(8),
            child: _HeaderChip(
              icon: AppIcons.event_outlined,
              label: Fmt.date(_date),
              accent: widget.accent,
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          Expanded(flex: 34, child: _productPanel()),
          const VerticalDivider(width: 1),
          Expanded(flex: 66, child: _cartPanel()),
        ],
      ),
    );
  }

  // ── Left: product list ─────────────────────────────────────────────
  Widget _productPanel() {
    final scheme = Theme.of(context).colorScheme;
    final products = _filtered;

    return Container(
      color: scheme.surface,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                AppIcon(AppIcons.inventory_2_outlined, size: 15, color: widget.accent),
                const SizedBox(width: 6),
                Text('Products',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: widget.accent)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.accent.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${products.length}',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: widget.accent)),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    onSubmitted: _onSearchSubmitted,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search or scan barcode…',
                      prefixIcon: const AppIcon(AppIcons.search, size: 10),
                      prefixIconConstraints:
                          const BoxConstraints(minWidth: 26, minHeight: 22),
                      suffixIcon: _searchCtrl.text.isEmpty
                          ? null
                          : GestureDetector(
                              onTap: () => setState(_searchCtrl.clear),
                              child: const AppIcon(AppIcons.close, size: 12),
                            ),
                      suffixIconConstraints:
                          const BoxConstraints(minWidth: 26, minHeight: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 72,
                  child: TextField(
                    controller: _qtyCtrl,
                    textAlign: TextAlign.center,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                    ],
                    style: TextStyle(
                        fontWeight: FontWeight.w800, color: widget.accent),
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Qty',
                    ),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                const SizedBox(width: 4),
                Expanded(
                  child: Text('Product',
                      style: _colStyle(scheme)),
                ),
                SizedBox(
                    width: 44,
                    child: Text('Unit',
                        textAlign: TextAlign.center, style: _colStyle(scheme))),
                SizedBox(
                    width: 72,
                    child: Text('Stock',
                        textAlign: TextAlign.right, style: _colStyle(scheme))),
              ]),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: products.isEmpty
              ? Center(
                  child: Text(
                    widget.products.isEmpty
                        ? 'No products yet — add them in Stock Inventory'
                        : 'No products match "${_searchCtrl.text.trim()}"',
                    style: TextStyle(color: scheme.outline),
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: products.length,
                  itemBuilder: (context, i) {
                    final p = products[i];
                    final highlighted = p.id == _highlightId;
                    return _ProductRow(
                      index: i + 1,
                      product: p,
                      accent: widget.accent,
                      highlighted: highlighted,
                      onTap: () => setState(() => _highlightId = p.id),
                      onAdd: () => _addProduct(p),
                    );
                  },
                ),
        ),
      ]),
    );
  }

  TextStyle _colStyle(ColorScheme scheme) => TextStyle(
      fontSize: 11, fontWeight: FontWeight.w700, color: scheme.outline);

  // ── Right: cart ────────────────────────────────────────────────────
  Widget _cartPanel() {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      color: scheme.surfaceContainerLowest,
      child: Column(children: [
        // Header: supplier + note
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
          ),
          child: Column(children: [
            Row(children: [
              Expanded(
                flex: 3,
                child: SearchableDropdown<PosParty>(
                  items: _party == null || widget.parties.contains(_party)
                      ? widget.parties
                      : [_party!, ...widget.parties],
                  value: _party,
                  itemLabel: (p) => p.name,
                  hintText: '${widget.partyHint} *',
                  onChanged: (v) => setState(() => _party = v),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 4,
                child: TextField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Note (optional)',
                  ),
                ),
              ),
            ]),
            if (widget.banks.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(children: [
                Expanded(
                  child: SearchableDropdown<int>(
                    items: [for (final b in widget.banks) b.id],
                    value: _bankId,
                    itemLabel: (id) => widget.banks
                        .firstWhere((b) => b.id == id,
                            orElse: () => const PosBankOption(id: -1, name: '—'))
                        .name,
                    hintText: widget.bankHint,
                    includeNull: true,
                    nullLabel: 'No bank (cash)',
                    onChanged: (v) => setState(() => _bankId = v),
                  ),
                ),
              ]),
            ],
          ]),
        ),
        Expanded(
          child: _lines.isEmpty
              ? _emptyCart(scheme)
              : Column(children: [
                  _cartHeader(scheme),
                  Expanded(
                    child: ListView.separated(
                      controller: _cartScrollCtrl,
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      itemCount: _lines.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (context, i) => _CartRow(
                        index: i + 1,
                        line: _lines[i],
                        accent: widget.accent,
                        showSalePrice: widget.showSecondaryPrice,
                        showDiscountAmount: widget.showLineDiscountAmount,
                        onRemove: () => _removeLine(_lines[i]),
                      ),
                    ),
                  ),
                ]),
        ),
        _summary(scheme),
      ]),
    );
  }

  Widget _emptyCart(ColorScheme scheme) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: widget.accent.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: AppIcon(AppIcons.shopping_cart_outlined,
                  size: 44, color: widget.accent),
            ),
            const SizedBox(height: 14),
            Text('Cart is empty',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text('Double-tap a product, or scan a barcode',
                style: TextStyle(fontSize: 12, color: scheme.outline)),
          ],
        ),
      );

  Widget _cartHeader(ColorScheme scheme) {
    final s = TextStyle(
        fontSize: 11, fontWeight: FontWeight.w700, color: scheme.outline);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 10, 12, 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: widget.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        SizedBox(width: 22, child: Text('#', style: s)),
        Expanded(flex: 4, child: Text('Product', style: s)),
        Expanded(flex: 2, child: Text('Qty', style: s, textAlign: TextAlign.center)),
        Expanded(
            flex: 2,
            child: Text(widget.priceLabel, style: s, textAlign: TextAlign.center)),
        if (widget.showSecondaryPrice)
          Expanded(flex: 2, child: Text('Sale', style: s, textAlign: TextAlign.center)),
        Expanded(flex: 2, child: Text('Disc %', style: s, textAlign: TextAlign.center)),
        if (widget.showLineDiscountAmount)
          Expanded(flex: 2, child: Text('Disc Rs', style: s, textAlign: TextAlign.center)),
        Expanded(flex: 2, child: Text('Tax %', style: s, textAlign: TextAlign.center)),
        Expanded(flex: 3, child: Text('Total', style: s, textAlign: TextAlign.right)),
        const SizedBox(width: 34),
      ]),
    );
  }

  Widget _summary(ColorScheme scheme) {
    Widget row(String label, double value, {Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
              Text(Fmt.money(value, decimals: true),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ],
          ),
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      child: Column(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Items', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
            Text('${_lines.length}  ·  ${_num(_totalUnits)} units',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
        row('Subtotal', _subtotal),
        row('Discount', -_discountTotal, color: const Color(0xFF2E7D32)),
        row('Tax', _taxTotal, color: const Color(0xFFC77700)),
        const Divider(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Grand Total',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: widget.accent)),
            Text(Fmt.money(_grandTotal, decimals: true),
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: widget.accent)),
          ],
        ),
        if (widget.showPrintReceiptToggle) ...[
          const SizedBox(height: 4),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => setState(() => _printReceipt = !_printReceipt),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _printReceipt,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    activeColor: widget.accent,
                    onChanged: (v) =>
                        setState(() => _printReceipt = v ?? false),
                  ),
                ),
                const SizedBox(width: 8),
                Text('Print receipt',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant)),
              ]),
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(children: [
          SizedBox(
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _lines.isEmpty ? null : _confirmClear,
              icon: const AppIcon(AppIcons.clear_all, size: 16),
              label: const Text('Clear'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFC62828),
                side: const BorderSide(color: Color(0xFFC62828)),
              ),
            ),
          ),
          if (widget.onHoldOrder != null) ...[
            const SizedBox(width: 10),
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed:
                    (_lines.isEmpty || widget.saving) ? null : _hold,
                icon: const AppIcon(AppIcons.pause_circle_outline, size: 16),
                label: const Text('Hold'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFC77700),
                  side: const BorderSide(color: Color(0xFFC77700)),
                ),
              ),
            ),
          ],
          const SizedBox(width: 10),
          Expanded(
            child: SizedBox(
              height: 44,
              child: FilledButton.icon(
                onPressed: widget.saving ? null : _submit,
                icon: widget.saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const AppIcon(AppIcons.check),
                label: Text(widget.submitLabel),
                style: FilledButton.styleFrom(backgroundColor: widget.accent),
              ),
            ),
          ),
        ]),
      ]),
    );
  }


  static String _num(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
}

// ── Held orders dialog ───────────────────────────────────────────────
class _HeldOrdersDialog extends StatefulWidget {
  const _HeldOrdersDialog({
    required this.orders,
    required this.accent,
    required this.onDelete,
  });

  final List<HeldOrder> orders;
  final Color accent;
  final void Function(HeldOrder order) onDelete;

  @override
  State<_HeldOrdersDialog> createState() => _HeldOrdersDialogState();
}

class _HeldOrdersDialogState extends State<_HeldOrdersDialog> {
  late final List<HeldOrder> _orders = List.of(widget.orders);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      title: const Text('Held invoices'),
      content: SizedBox(
        width: 420,
        child: _orders.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No held invoices left.'),
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: _orders.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final o = _orders[i];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(o.title,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      '${o.itemCount} item(s) · ${Fmt.money(o.total)}'
                      '${o.heldBy.isEmpty ? '' : ' · ${o.heldBy}'}'
                      ' · ${_ago(o.heldAt)}',
                      style: TextStyle(fontSize: 12, color: scheme.outline),
                    ),
                    trailing: IconButton(
                      tooltip: 'Discard',
                      icon: const AppIcon(AppIcons.delete_outline,
                          size: 18, color: Color(0xFFC62828)),
                      onPressed: () {
                        widget.onDelete(o);
                        setState(() => _orders.removeAt(i));
                      },
                    ),
                    onTap: () => Navigator.pop(context, o),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return Fmt.date(t);
  }
}

// ── Header chip ──────────────────────────────────────────────────────
class _HeaderChip extends StatelessWidget {
  const _HeaderChip(
      {required this.icon, required this.label, required this.accent});

  final String icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        AppIcon(icon, size: 13, color: accent),
        const SizedBox(width: 6),
        Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: accent)),
      ]),
    );
  }
}

// ── Product row ──────────────────────────────────────────────────────

/// Formats an on-hand quantity: `12` when whole, `12.5` otherwise.
String _stockLabel(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.index,
    required this.product,
    required this.accent,
    required this.highlighted,
    required this.onTap,
    required this.onAdd,
  });

  final int index;
  final PosProduct product;
  final Color accent;
  final bool highlighted;
  final VoidCallback onTap;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: highlighted ? accent.withValues(alpha: 0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        onDoubleTap: onAdd,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(children: [
            SizedBox(
              width: 22,
              child: Text('$index',
                  style: TextStyle(fontSize: 11, color: scheme.outline)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: highlighted ? accent : scheme.onSurface)),
                  if (product.barcode.isNotEmpty)
                    Text(product.barcode,
                        style: TextStyle(fontSize: 10, color: scheme.outline)),
                ],
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(product.unit,
                  textAlign: TextAlign.center,
                  style:
                      TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            ),
            SizedBox(
              width: 72,
              child: Text(_stockLabel(product.stock),
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: product.stock <= 0
                          ? scheme.error
                          : scheme.onSurface)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Cart row ─────────────────────────────────────────────────────────
class _CartRow extends StatelessWidget {
  const _CartRow({
    required this.index,
    required this.line,
    required this.accent,
    required this.showSalePrice,
    required this.showDiscountAmount,
    required this.onRemove,
  });

  final int index;
  final PosLine line;
  final Color accent;
  final bool showSalePrice;
  final bool showDiscountAmount;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 22,
            child: Text('$index',
                style: TextStyle(fontSize: 12, color: scheme.outline)),
          ),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(line.product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                if (line.product.barcode.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(line.product.barcode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: scheme.outline)),
                ],
              ],
            ),
          ),
          Expanded(flex: 2, child: _cell(context, line.qtyCtrl)),
          Expanded(flex: 2, child: _cell(context, line.priceCtrl)),
          if (showSalePrice)
            Expanded(flex: 2, child: _cell(context, line.salePriceCtrl)),
          Expanded(flex: 2, child: _cell(context, line.discCtrl)),
          if (showDiscountAmount)
            Expanded(flex: 2, child: _cell(context, line.discAmtCtrl)),
          Expanded(flex: 2, child: _cell(context, line.taxCtrl)),
          Expanded(
            flex: 3,
            child: Text(Fmt.money(line.lineTotal, decimals: true),
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: accent)),
          ),
          SizedBox(
            width: 34,
            child: IconButton(
              tooltip: 'Remove',
              visualDensity: VisualDensity.compact,
              icon: const AppIcon(AppIcons.delete_outline,
                  size: 17, color: Color(0xFFC62828)),
              onPressed: onRemove,
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(BuildContext context, TextEditingController c) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(8);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: TextField(
        controller: c,
        textAlign: TextAlign.center,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
        ],
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          border: OutlineInputBorder(
              borderRadius: radius, borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
              borderRadius: radius, borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: radius, borderSide: BorderSide.none),
        ),
      ),
    );
  }
}
