import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pos/shared/app_icon.dart';

import '../../../../config/format.dart';
import '../../../../shared/feature_ui.dart';
import '../../../../shared/receipt/barcode_label.dart';
import '../../../../shared/receipt/receipt_printer.dart';
import '../../../login/data/permissions.dart';
import '../../../login/presentation/access_scope.dart';
import '../../data/model/stock_item_model.dart';
import '../provider/stock_inventory_provider.dart';
import '../widget/stock_item_form_dialog.dart';

String _num(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

/// Stock Inventory module: a single product catalogue.
class StockInventoryScreen extends StatefulWidget {
  const StockInventoryScreen({super.key, this.provider});

  static const String routeName = '/stock_inventory';

  final StockInventoryProvider? provider;

  @override
  State<StockInventoryScreen> createState() => _StockInventoryScreenState();
}

class _StockInventoryScreenState extends State<StockInventoryScreen> {
  late final StockInventoryProvider _provider =
      widget.provider ?? StockInventoryProvider();

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

  Future<void> _openForm([StockItemModel? existing]) async {
    final result = await showDialog<StockItemModel>(
      context: context,
      builder: (_) => StockItemFormDialog(
        initial: existing,
        companies: _provider.companies,
        categories: _provider.categories,
        inventoryTypes: _provider.inventoryTypes,
      ),
    );
    if (result == null) return;
    final ok = await _provider.save(result);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Product "${result.name}" saved')),
      );
    }
  }

  /// Prints a scannable Code 128 barcode label for [i] on the thermal printer.
  Future<void> _printBarcode(StockItemModel i) async {
    await ReceiptPrinter.instance.printReceipt(
      context,
      buildBarcodeLabelPdf(
        barcode: i.barcode,
        productName: i.name,
        priceLabel: 'Rs ${Fmt.money(i.salePrice)}',
      ),
      pageFormat: PdfPageFormat.roll80,
      onError: (msg) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg)));
        }
      },
    );
  }

  Future<void> _confirmDelete(StockItemModel i) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete product?'),
        content: Text('"${i.name}" will be permanently removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (yes != true) return;
    final ok = await _provider.delete(i.id!);
    if (!mounted) return;
    if (!ok && _provider.error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(_provider.error!)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = AccessScope.of(context);
    final canAdd = access.can('stock_inventory', PermAction.add);
    final canEdit = access.can('stock_inventory', PermAction.edit);
    final canDelete = access.can('stock_inventory', PermAction.delete);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stock Inventory'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const AppIcon(AppIcons.refresh),
            onPressed: _provider.load,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListenableBuilder(
        listenable: _provider,
        builder: (context, _) {
          if (_provider.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_provider.error != null) {
            return ErrorState(message: _provider.error!, onRetry: _provider.load);
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                child: StatCardRow(
                  cards: [
                    StatCard(
                      title: 'Products',
                      subtitle: '${_provider.items.length}',
                    ),
                    StatCard(
                      title: 'Active',
                      subtitle: '${_provider.activeCount}',
                      tint: const Color(0xFF2E7D32),
                    ),
                    StatCard(
                      title: 'Categories',
                      subtitle: '${_provider.categoryCount}',
                      tint: const Color(0xFF6A1B9A),
                    ),
                    StatCard(
                      title: 'Units in Stock',
                      subtitle: _num(_provider.unitsOnHand),
                      tint: const Color(0xFF1565C0),
                    ),
                    StatCard(
                      title: 'Stock Value',
                      subtitle: Fmt.money(_provider.stockValue),
                      tint: const Color(0xFF00695C),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                  child: SectionCard(
                    title: 'Products',
                    subtitle: 'Inventory catalogue',
                    fillHeight: true,
                    trailing: canAdd
                        ? FilledButton.icon(
                            onPressed: () => _openForm(),
                            icon: const AppIcon(AppIcons.add),
                            label: const Text('Add Product'),
                          )
                        : null,
                    child: _provider.items.isEmpty
                        ? EmptyState(
                            icon: AppIcons.inventory_2_outlined,
                            title: 'No products yet',
                            actionLabel: canAdd ? 'Add Product' : null,
                            onAction: canAdd ? () => _openForm() : null,
                          )
                        : ScrollableTable(
                            flexColumn: 1, // Product
                            columnSpacing: 22,
                            columns: const [
                              DataColumn(label: Text('Barcode')),
                              DataColumn(label: Text('Product')),
                              DataColumn(label: Text('SKU')),
                              DataColumn(label: Text('Company')),
                              DataColumn(label: Text('Inventory Type')),
                              DataColumn(label: Text('Category')),
                              DataColumn(label: Text('Purchase'), numeric: true),
                              DataColumn(label: Text('Sale'), numeric: true),
                              DataColumn(label: Text('Stock'), numeric: true),
                              DataColumn(label: Text('Disc %'), numeric: true),
                              DataColumn(label: Text('Tax %'), numeric: true),
                              DataColumn(label: Text('Expiry')),
                              DataColumn(label: Text('Unit')),
                              DataColumn(label: Text('Active')),
                              DataColumn(label: Text('')),
                            ],
                            rows: [
                              for (final i in _provider.items)
                                DataRow(
                                  onSelectChanged:
                                      canEdit ? (_) => _openForm(i) : null,
                                  cells: [
                                    DataCell(i.barcode.isEmpty
                                        ? const Text('—')
                                        : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Flexible(
                                                child: Text(i.barcode,
                                                    overflow:
                                                        TextOverflow.ellipsis),
                                              ),
                                              const SizedBox(width: 2),
                                              IconButton(
                                                tooltip: 'Print barcode',
                                                visualDensity:
                                                    VisualDensity.compact,
                                                padding: EdgeInsets.zero,
                                                constraints: const BoxConstraints(
                                                    minWidth: 30, minHeight: 30),
                                                icon: const AppIcon(
                                                    AppIcons.print_outlined,
                                                    size: 16),
                                                onPressed: () =>
                                                    _printBarcode(i),
                                              ),
                                            ],
                                          )),
                                    DataCell(Text(i.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600))),
                                    DataCell(Text(i.sku)),
                                    DataCell(Text(i.companyName)),
                                    DataCell(i.inventoryType.isEmpty
                                        ? const Text('')
                                        : StatusPill(
                                            text: i.inventoryType,
                                            color: Colors.blueGrey)),
                                    DataCell(Text(i.category)),
                                    DataCell(Text(Fmt.money(i.purchasePrice,
                                        decimals: true))),
                                    DataCell(Text(
                                        Fmt.money(i.salePrice, decimals: true))),
                                    DataCell(Text(_num(i.quantity),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600))),
                                    DataCell(Text('${_num(i.discount)}%')),
                                    DataCell(Text('${_num(i.tax)}%')),
                                    DataCell(Text(i.expiryDate == null
                                        ? '—'
                                        : Fmt.date(i.expiryDate!))),
                                    DataCell(Text(i.unit)),
                                    DataCell(ActiveDot(active: i.isActive)),
                                    DataCell(RowActions(
                                      onEdit:
                                          canEdit ? () => _openForm(i) : null,
                                      onDelete: canDelete
                                          ? () => _confirmDelete(i)
                                          : null,
                                    )),
                                  ],
                                ),
                            ],
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
