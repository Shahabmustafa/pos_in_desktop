import 'package:flutter/material.dart';
import 'package:pos/shared/app_icon.dart';

import '../../../../config/format.dart';
import '../../../../shared/export/export_button.dart';
import '../../../../shared/export/export_doc.dart';
import '../../../../shared/feature_ui.dart';
import '../../data/model/reports_model.dart';
import '../provider/reports_provider.dart';
import 'reports_export.dart';

/// Reports module — pick a report and a date range; the table and summary
/// update. Rows with a **View** button open a right-hand detail panel.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, this.provider});

  static const String routeName = '/reports';

  final ReportsProvider? provider;

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late final ReportsProvider _provider = widget.provider ?? ReportsProvider();

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

  Future<void> _pickRange() async {
    final picked = await showDialog<DateTimeRange>(
      context: context,
      builder: (_) => _DateRangeDialog(initial: _provider.range),
    );
    if (picked != null) await _provider.setRange(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          ListenableBuilder(
            listenable: _provider,
            builder: (context, _) => ExportButton(
              enabled: !_provider.loading && _provider.error == null,
              builder: () => buildReportExport(_provider),
            ),
          ),
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
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Toolbar(provider: _provider, onPickRange: _pickRange),
              const Divider(height: 1),
              Expanded(
                child: Builder(builder: (context) {
                  if (_provider.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (_provider.error != null) {
                    return ErrorState(
                        message: _provider.error!, onRetry: _provider.load);
                  }
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: _ReportBody(provider: _provider),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.provider, required this.onPickRange});

  final ReportsProvider provider;
  final VoidCallback onPickRange;

  @override
  Widget build(BuildContext context) {
    final r = provider.range;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        children: [
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in ReportType.values)
                  ChoiceChip(
                    label: Text(t.label),
                    selected: provider.type == t,
                    onSelected: (_) => provider.setType(t),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          OutlinedButton.icon(
            onPressed: onPickRange,
            icon: const AppIcon(AppIcons.event, size: 16),
            label: Text('${Fmt.date(r.start)}  →  ${Fmt.date(r.end)}'),
          ),
        ],
      ),
    );
  }
}

String _qty(double v) =>
    v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

/// Table on the left, an optional detail panel on the right.
Widget _masterDetail({required Widget table, Widget? panel}) {
  if (panel == null) return table;
  return Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Expanded(child: table),
      const VerticalDivider(width: 25),
      SizedBox(width: 400, child: panel),
    ],
  );
}

/// Compact "open the detail panel" action for a table row.
Widget _viewButton(VoidCallback onPressed) => IconButton(
      tooltip: 'View details',
      visualDensity: VisualDensity.compact,
      icon: const AppIcon(AppIcons.visibility_outlined, size: 18),
      onPressed: onPressed,
    );

class _ReportBody extends StatelessWidget {
  const _ReportBody({required this.provider});

  final ReportsProvider provider;

  @override
  Widget build(BuildContext context) {
    switch (provider.type) {
      case ReportType.sale:
        return _SaleReport(provider: provider);
      case ReportType.saleReturn:
        return _SaleReturnReport(provider: provider);
      case ReportType.saleExchange:
        return _SaleExchangeReport(provider: provider);
      case ReportType.purchase:
        return _PurchaseReport(provider: provider);
      case ReportType.category:
        return _CategoryReport(provider: provider);
      case ReportType.stock:
        return _StockReport(provider: provider);
      case ReportType.expense:
        return _ExpenseReport(rows: provider.expenseRows);
      case ReportType.profitLoss:
        return _ProfitLossReport(provider: provider);
    }
  }
}

// ═══════════════════════════════════ Sale ═══════════════════════════════════

class _SaleReport extends StatelessWidget {
  const _SaleReport({required this.provider});

  final ReportsProvider provider;

  @override
  Widget build(BuildContext context) {
    final rows = provider.saleRows;
    final selected = provider.selectedSale;

    final table = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatCardRow(cards: [
          StatCard(title: 'Invoices', subtitle: '${rows.length}'),
          StatCard(
              title: 'Total discount',
              subtitle: Fmt.money(rows.fold<double>(0, (a, r) => a + r.discount))),
          StatCard(
              title: 'Sub total',
              subtitle: Fmt.money(rows.fold<double>(0, (a, r) => a + r.subtotal))),
          StatCard(
              title: 'Total amount',
              subtitle: Fmt.money(
                  rows.fold<double>(0, (a, r) => a + r.grandTotal)),
              tint: const Color(0xFF2E7D32)),
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: SectionCard(
            fillHeight: true,
            child: rows.isEmpty
                ? const EmptyState(
                    icon: AppIcons.bar_chart_outlined,
                    title: 'No sales in this date range')
                : ScrollableTable(
                    flexColumn: selected == null ? 2 : -1,
                    columns: const [
                      DataColumn(label: Text('Invoice No.')),
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Customer Name')),
                      DataColumn(label: Text('Total Discount'), numeric: true),
                      DataColumn(label: Text('Sub Total'), numeric: true),
                      DataColumn(label: Text('Total Amount'), numeric: true),
                      DataColumn(label: Text('')),
                    ],
                    rows: [
                      for (final inv in rows)
                        DataRow(
                          selected: selected?.invoiceNo == inv.invoiceNo,
                          cells: [
                            DataCell(Text(inv.invoiceNo)),
                            DataCell(Text(Fmt.date(inv.date))),
                            DataCell(Text(
                                inv.customer.isEmpty ? '—' : inv.customer)),
                            DataCell(Text(Fmt.money(inv.discount))),
                            DataCell(Text(Fmt.money(inv.subtotal))),
                            DataCell(Text(Fmt.money(inv.grandTotal),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700))),
                            DataCell(_viewButton(
                                () => provider.selectSale(inv))),
                          ],
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );

    return _masterDetail(
      table: table,
      panel: selected == null
          ? null
          : _DetailPanel(
              title: selected.invoiceNo,
              subtitle: '${Fmt.date(selected.date)}  ·  '
                  '${selected.customer.isEmpty ? "No customer" : selected.customer}',
              onClose: () => provider.selectSale(null),
              body: _ItemsTable(items: selected.items),
              totals: [
                ('Sub Total', selected.subtotal),
                ('Discount', selected.discount),
                if (selected.tax != 0) ('Tax', selected.tax),
                ('Total Amount', selected.grandTotal),
              ],
            ),
    );
  }
}

// ═══════════════════════════════ Sale Return ════════════════════════════════

class _SaleReturnReport extends StatelessWidget {
  const _SaleReturnReport({required this.provider});

  final ReportsProvider provider;

  @override
  Widget build(BuildContext context) {
    final rows = provider.saleReturnRows;
    final selected = provider.selectedSaleReturn;

    final table = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatCardRow(cards: [
          StatCard(title: 'Returns', subtitle: '${rows.length}'),
          StatCard(
              title: 'Qty returned',
              subtitle: _qty(rows.fold<double>(0, (a, r) => a + r.quantity))),
          StatCard(
              title: 'Return value',
              subtitle: Fmt.money(
                  rows.fold<double>(0, (a, r) => a + r.grandTotal)),
              tint: const Color(0xFFC62828)),
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: SectionCard(
            fillHeight: true,
            child: rows.isEmpty
                ? const EmptyState(
                    icon: AppIcons.bar_chart_outlined,
                    title: 'No sale returns in this date range')
                : ScrollableTable(
                    flexColumn: selected == null ? 2 : -1,
                    columns: const [
                      DataColumn(label: Text('Return No.')),
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Customer Name')),
                      DataColumn(label: Text('Qty'), numeric: true),
                      DataColumn(label: Text('Return Value'), numeric: true),
                      DataColumn(label: Text('')),
                    ],
                    rows: [
                      for (final inv in rows)
                        DataRow(
                          selected: selected?.invoiceNo == inv.invoiceNo,
                          cells: [
                            DataCell(Text(inv.invoiceNo)),
                            DataCell(Text(Fmt.date(inv.date))),
                            DataCell(Text(
                                inv.customer.isEmpty ? '—' : inv.customer)),
                            DataCell(Text(_qty(inv.quantity))),
                            DataCell(Text(Fmt.money(inv.grandTotal),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700))),
                            DataCell(_viewButton(
                                () => provider.selectSaleReturn(inv))),
                          ],
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );

    return _masterDetail(
      table: table,
      panel: selected == null
          ? null
          : _DetailPanel(
              title: selected.invoiceNo,
              subtitle: '${Fmt.date(selected.date)}  ·  '
                  '${selected.customer.isEmpty ? "No customer" : selected.customer}',
              onClose: () => provider.selectSaleReturn(null),
              body: _ItemsTable(items: selected.items),
              totals: [('Return Value', selected.grandTotal)],
            ),
    );
  }
}

// ═══════════════════════════════ Sale Exchange ══════════════════════════════

class _SaleExchangeReport extends StatelessWidget {
  const _SaleExchangeReport({required this.provider});

  final ReportsProvider provider;

  @override
  Widget build(BuildContext context) {
    final rows = provider.saleExchangeRows;
    final selected = provider.selectedSaleExchange;
    final diff = rows.fold<double>(0, (a, r) => a + r.difference);

    final table = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatCardRow(cards: [
          StatCard(title: 'Exchanges', subtitle: '${rows.length}'),
          StatCard(
              title: 'Net difference',
              subtitle: Fmt.money(diff),
              tint: diff < 0
                  ? const Color(0xFFC62828)
                  : const Color(0xFF2E7D32)),
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: SectionCard(
            fillHeight: true,
            child: rows.isEmpty
                ? const EmptyState(
                    icon: AppIcons.swap_horiz_outlined,
                    title: 'No exchanges in this date range')
                : ScrollableTable(
                    flexColumn: selected == null ? 3 : -1,
                    columns: const [
                      DataColumn(label: Text('Exchange No.')),
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Against Invoice')),
                      DataColumn(label: Text('Customer')),
                      DataColumn(label: Text('Old Total'), numeric: true),
                      DataColumn(label: Text('New Total'), numeric: true),
                      DataColumn(label: Text('Difference'), numeric: true),
                      DataColumn(label: Text('')),
                    ],
                    rows: [
                      for (final ex in rows)
                        DataRow(
                          selected: selected?.exchangeNo == ex.exchangeNo,
                          cells: [
                            DataCell(Text(ex.exchangeNo)),
                            DataCell(Text(Fmt.date(ex.date))),
                            DataCell(Text(
                                ex.invoiceNo.isEmpty ? '—' : ex.invoiceNo)),
                            DataCell(Text(
                                ex.customer.isEmpty ? '—' : ex.customer)),
                            DataCell(Text(Fmt.money(ex.oldTotal))),
                            DataCell(Text(Fmt.money(ex.newTotal))),
                            DataCell(Text(Fmt.money(ex.difference),
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: ex.difference < 0
                                        ? const Color(0xFFC62828)
                                        : const Color(0xFF2E7D32)))),
                            DataCell(_viewButton(
                                () => provider.selectSaleExchange(ex))),
                          ],
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );

    return _masterDetail(
      table: table,
      panel: selected == null
          ? null
          : _DetailPanel(
              title: selected.exchangeNo,
              subtitle: '${Fmt.date(selected.date)}  ·  '
                  '${selected.invoiceNo.isEmpty ? "invoice" : selected.invoiceNo}'
                  '  ·  '
                  '${selected.customer.isEmpty ? "No customer" : selected.customer}',
              onClose: () => provider.selectSaleExchange(null),
              body: _MiniTable(
                columns: const ['Type', 'Product', 'Qty', 'Price', 'Amount'],
                rows: [
                  for (final l in selected.outLines)
                    [
                      'Returned',
                      l.productName,
                      '${_qty(l.quantity)} ${l.unit}',
                      Fmt.money(l.salePrice),
                      Fmt.money(l.lineTotal),
                    ],
                  for (final l in selected.inLines)
                    [
                      'Added',
                      l.productName,
                      '${_qty(l.quantity)} ${l.unit}',
                      Fmt.money(l.salePrice),
                      Fmt.money(l.lineTotal),
                    ],
                ],
              ),
              totals: [
                ('Old Total', selected.oldTotal),
                ('New Total', selected.newTotal),
                ('Difference', selected.difference),
              ],
            ),
    );
  }
}

// ═══════════════════════════════ Profit & Loss ══════════════════════════════

class _ProfitLossReport extends StatelessWidget {
  const _ProfitLossReport({required this.provider});

  final ReportsProvider provider;

  @override
  Widget build(BuildContext context) {
    final pl = provider.profitLoss;
    final drill = provider.plDrill;

    final summary = SingleChildScrollView(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SectionCard(
            title: 'Profit & Loss',
            subtitle: 'For the selected date range',
            child: Column(
              children: [
                _row(context, 'Gross Sales', pl.grossSales,
                    onView: pl.saleInvoices.isEmpty
                        ? null
                        : () => provider.setPlDrill(PlDrill.sales),
                    active: drill == PlDrill.sales),
                _row(context, 'Less: Sale Returns', -pl.saleReturns,
                    onView: pl.saleReturnInvoices.isEmpty
                        ? null
                        : () => provider.setPlDrill(PlDrill.returns),
                    active: drill == PlDrill.returns),
                const Divider(),
                _row(context, 'Net Sales', pl.netSales, strong: true),
                _row(context, 'Less: Cost of Goods Sold', -pl.cogs),
                const Divider(),
                _row(context, 'Gross Profit', pl.grossProfit, strong: true),
                _row(context, 'Less: Expenses', -pl.expenses,
                    onView: pl.expenseEntries.isEmpty
                        ? null
                        : () => provider.setPlDrill(PlDrill.expenses),
                    active: drill == PlDrill.expenses),
                const Divider(thickness: 1.4),
                _row(context, 'Net Profit', pl.netProfit,
                    strong: true, big: true),
              ],
            ),
          ),
        ),
      ),
    );

    Widget? panel;
    switch (drill) {
      case PlDrill.none:
        panel = null;
      case PlDrill.sales:
        panel = _DetailPanel(
          title: 'Gross Sales',
          subtitle: '${pl.saleInvoices.length} invoice(s)',
          onClose: () => provider.setPlDrill(PlDrill.none),
          body: _MiniTable(
            columns: const ['Invoice', 'Date', 'Customer', 'Amount'],
            rows: [
              for (final i in pl.saleInvoices)
                [
                  i.invoiceNo,
                  Fmt.date(i.date),
                  i.customer.isEmpty ? '—' : i.customer,
                  Fmt.money(i.grandTotal),
                ],
            ],
          ),
          totals: [('Gross Sales', pl.grossSales)],
        );
      case PlDrill.returns:
        panel = _DetailPanel(
          title: 'Sale Returns',
          subtitle: '${pl.saleReturnInvoices.length} return(s)',
          onClose: () => provider.setPlDrill(PlDrill.none),
          body: _MiniTable(
            columns: const ['Return', 'Date', 'Customer', 'Value'],
            rows: [
              for (final i in pl.saleReturnInvoices)
                [
                  i.invoiceNo,
                  Fmt.date(i.date),
                  i.customer.isEmpty ? '—' : i.customer,
                  Fmt.money(i.grandTotal),
                ],
            ],
          ),
          totals: [('Sale Returns', pl.saleReturns)],
        );
      case PlDrill.expenses:
        panel = _DetailPanel(
          title: 'Expenses',
          subtitle: '${pl.expenseEntries.length} entr(y/ies)',
          onClose: () => provider.setPlDrill(PlDrill.none),
          body: _MiniTable(
            columns: const ['Date', 'Head', 'Mode', 'Amount'],
            rows: [
              for (final e in pl.expenseEntries)
                [
                  Fmt.date(e.date),
                  e.head,
                  e.paymentMode,
                  Fmt.money(e.amount),
                ],
            ],
          ),
          totals: [('Expenses', pl.expenses)],
        );
    }

    return _masterDetail(table: summary, panel: panel);
  }

  Widget _row(BuildContext context, String label, double value,
      {bool strong = false,
      bool big = false,
      VoidCallback? onView,
      bool active = false}) {
    final color = big
        ? (value < 0 ? const Color(0xFFC62828) : const Color(0xFF2E7D32))
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(
                  fontSize: big ? 16 : 14,
                  fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
                )),
          ),
          if (onView != null)
            TextButton(
              onPressed: onView,
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: active
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
              child: const Text('View'),
            ),
          const SizedBox(width: 8),
          Text(
            Fmt.money(value),
            style: TextStyle(
              fontSize: big ? 18 : 14,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════ Category-wise ══════════════════════════════

class _CategoryReport extends StatelessWidget {
  const _CategoryReport({required this.provider});

  final ReportsProvider provider;

  @override
  Widget build(BuildContext context) {
    final rows = provider.categoryRows;
    final selected = provider.selectedCategory;
    final sale = rows.fold<double>(0, (a, r) => a + r.saleValue);
    final cost = rows.fold<double>(0, (a, r) => a + r.cost);

    final table = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatCardRow(cards: [
          StatCard(title: 'Categories', subtitle: '${rows.length}'),
          StatCard(title: 'Sale value', subtitle: Fmt.money(sale)),
          StatCard(title: 'Cost', subtitle: Fmt.money(cost)),
          StatCard(
              title: 'Profit',
              subtitle: Fmt.money(sale - cost),
              tint: (sale - cost) < 0
                  ? const Color(0xFFC62828)
                  : const Color(0xFF2E7D32)),
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: SectionCard(
            fillHeight: true,
            child: rows.isEmpty
                ? const EmptyState(
                    icon: AppIcons.category_outlined,
                    title: 'No sales in this date range')
                : ScrollableTable(
                    flexColumn: selected == null ? 0 : -1,
                    columns: const [
                      DataColumn(label: Text('Category')),
                      DataColumn(label: Text('Qty'), numeric: true),
                      DataColumn(label: Text('Sale value'), numeric: true),
                      DataColumn(label: Text('Cost'), numeric: true),
                      DataColumn(label: Text('Profit'), numeric: true),
                      DataColumn(label: Text('Margin'), numeric: true),
                      DataColumn(label: Text('')),
                    ],
                    rows: [
                      for (final row in rows)
                        DataRow(
                          selected: selected?.category == row.category,
                          cells: [
                            DataCell(Text(row.category,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600))),
                            DataCell(Text(_qty(row.quantity))),
                            DataCell(Text(Fmt.money(row.saleValue))),
                            DataCell(Text(Fmt.money(row.cost))),
                            DataCell(Text(Fmt.money(row.profit),
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: row.profit < 0
                                        ? const Color(0xFFC62828)
                                        : const Color(0xFF2E7D32)))),
                            DataCell(
                                Text('${row.margin.toStringAsFixed(1)}%')),
                            DataCell(_viewButton(
                                () => provider.selectCategory(row))),
                          ],
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );

    return _masterDetail(
      table: table,
      panel: selected == null
          ? null
          : _DetailPanel(
              title: selected.category,
              subtitle: '${selected.items.length} product(s)',
              onClose: () => provider.selectCategory(null),
              body: _MiniTable(
                columns: const ['Product', 'Qty', 'Sale', 'Cost', 'Profit'],
                rows: [
                  for (final p in selected.items)
                    [
                      p.product,
                      _qty(p.quantity),
                      Fmt.money(p.saleValue),
                      Fmt.money(p.cost),
                      Fmt.money(p.profit),
                    ],
                ],
              ),
              totals: [
                ('Sale value', selected.saleValue),
                ('Cost', selected.cost),
                ('Profit', selected.profit),
              ],
            ),
    );
  }
}

// ═══════════════════════════════════ Stock ══════════════════════════════════

class _StockReport extends StatelessWidget {
  const _StockReport({required this.provider});

  final ReportsProvider provider;

  @override
  Widget build(BuildContext context) {
    final rows = provider.stockRows;
    final selected = provider.selectedStock;
    final purchased = rows.fold<double>(0, (a, r) => a + r.purchased);
    final sold = rows.fold<double>(0, (a, r) => a + r.sold);
    final returned = rows.fold<double>(
        0, (a, r) => a + r.saleReturned + r.purchaseReturned);

    final table = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatCardRow(cards: [
          StatCard(title: 'Products', subtitle: '${rows.length}'),
          StatCard(title: 'Purchased', subtitle: _qty(purchased)),
          StatCard(title: 'Sold', subtitle: _qty(sold)),
          StatCard(title: 'Returned', subtitle: _qty(returned)),
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: SectionCard(
            fillHeight: true,
            child: rows.isEmpty
                ? const EmptyState(
                    icon: AppIcons.inventory_2_outlined,
                    title: 'No products / no movement in this date range')
                : ScrollableTable(
                    flexColumn: selected == null ? 0 : -1,
                    columns: const [
                      DataColumn(label: Text('Product')),
                      DataColumn(label: Text('Opening'), numeric: true),
                      DataColumn(label: Text('Purchased'), numeric: true),
                      DataColumn(label: Text('Sold'), numeric: true),
                      DataColumn(label: Text('Sale Ret.'), numeric: true),
                      DataColumn(label: Text('Purch. Ret.'), numeric: true),
                      DataColumn(label: Text('Closing'), numeric: true),
                      DataColumn(label: Text('')),
                    ],
                    rows: [
                      for (final r in rows)
                        DataRow(
                          selected: selected?.productId == r.productId,
                          cells: [
                            DataCell(Text(r.product,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600))),
                            DataCell(Text(_qty(r.opening))),
                            DataCell(Text(r.purchased == 0
                                ? '—'
                                : _qty(r.purchased))),
                            DataCell(
                                Text(r.sold == 0 ? '—' : _qty(r.sold))),
                            DataCell(Text(r.saleReturned == 0
                                ? '—'
                                : _qty(r.saleReturned))),
                            DataCell(Text(r.purchaseReturned == 0
                                ? '—'
                                : _qty(r.purchaseReturned))),
                            DataCell(Text(_qty(r.closing),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700))),
                            DataCell(r.hasMovement
                                ? _viewButton(() => provider.selectStock(r))
                                : const SizedBox.shrink()),
                          ],
                        ),
                    ],
                  ),
          ),
        ),
      ],
    );

    return _masterDetail(
      table: table,
      panel: selected == null
          ? null
          : _DetailPanel(
              title: selected.product,
              subtitle: '${selected.movements.length} movement(s)  ·  '
                  'opening ${_qty(selected.opening)} → '
                  'closing ${_qty(selected.closing)}',
              onClose: () => provider.selectStock(null),
              moneyTotals: false,
              body: _MiniTable(
                columns: const [
                  'Date',
                  'Type',
                  'Doc #',
                  'Party',
                  'Qty',
                  'Rate',
                  'Amount',
                ],
                rows: [
                  for (final m in selected.movements)
                    [
                      Fmt.date(m.date),
                      m.type,
                      m.docNo,
                      m.party.isEmpty ? '—' : m.party,
                      '${m.delta > 0 ? '+' : ''}${_qty(m.delta)} ${selected.unit}',
                      m.price == 0 ? '—' : Fmt.money(m.price),
                      m.amount == 0 ? '—' : Fmt.money(m.amount),
                    ],
                ],
              ),
              totals: [
                ('Opening', selected.opening),
                ('Net change', selected.netChange),
                ('Closing', selected.closing),
              ],
            ),
    );
  }
}

// ═══════════════════════════════════ Expense ════════════════════════════════

class _ExpenseReport extends StatelessWidget {
  const _ExpenseReport({required this.rows});

  final List<ExpenseReportRow> rows;

  @override
  Widget build(BuildContext context) {
    final total = rows.fold<double>(0, (a, r) => a + r.amount);
    final cash = rows
        .where((r) => r.paymentMode.toLowerCase() == 'cash')
        .fold<double>(0, (a, r) => a + r.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatCardRow(cards: [
          StatCard(title: 'Entries', subtitle: '${rows.length}'),
          StatCard(title: 'Cash', subtitle: Fmt.money(cash)),
          StatCard(title: 'Bank / other', subtitle: Fmt.money(total - cash)),
          StatCard(
              title: 'Total expense',
              subtitle: Fmt.money(total),
              tint: const Color(0xFFC62828)),
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: SectionCard(
            fillHeight: true,
            child: rows.isEmpty
                ? const EmptyState(
                    icon: AppIcons.payments_outlined,
                    title: 'No expenses in this date range')
                : ScrollableTable(
                    flexColumn: 4,
                    columns: const [
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Head')),
                      DataColumn(label: Text('Amount'), numeric: true),
                      DataColumn(label: Text('Mode')),
                      DataColumn(label: Text('Description')),
                    ],
                    rows: [
                      for (final row in rows)
                        DataRow(cells: [
                          DataCell(Text(Fmt.date(row.date))),
                          DataCell(Text(row.head)),
                          DataCell(Text(Fmt.money(row.amount),
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700))),
                          DataCell(Text(row.paymentMode)),
                          DataCell(Text(row.description)),
                        ]),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════ Purchase + Purchase Return ═════════════════════

class _PurchaseReport extends StatelessWidget {
  const _PurchaseReport({required this.provider});

  final ReportsProvider provider;

  @override
  Widget build(BuildContext context) {
    final data = provider.purchaseData;
    final selected = provider.selectedPurchase;
    final purchases = data.purchases;

    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatCardRow(cards: [
          StatCard(
              title: 'Purchases', subtitle: Fmt.money(data.purchaseTotal)),
          StatCard(title: 'Invoices', subtitle: '${purchases.length}'),
          StatCard(
              title: 'Purchase returns',
              subtitle: Fmt.money(data.returnTotal),
              tint: const Color(0xFFC62828)),
          StatCard(
              title: 'Net purchase',
              subtitle: Fmt.money(data.netPurchase),
              tint: const Color(0xFF2E7D32)),
        ]),
        const SizedBox(height: 16),
        Expanded(
          flex: 3,
          child: SectionCard(
            title: 'Purchase Invoices',
            fillHeight: true,
            child: purchases.isEmpty
                ? const EmptyState(
                    icon: AppIcons.shopping_cart_outlined,
                    title: 'No purchases in this date range')
                : ScrollableTable(
                    flexColumn: selected == null ? 2 : -1,
                    columns: const [
                      DataColumn(label: Text('Invoice No.')),
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Supplier')),
                      DataColumn(label: Text('Discount'), numeric: true),
                      DataColumn(label: Text('Sub Total'), numeric: true),
                      DataColumn(label: Text('Total Amount'), numeric: true),
                      DataColumn(label: Text('')),
                    ],
                    rows: [
                      for (final inv in purchases)
                        DataRow(
                          selected: selected?.invoiceNo == inv.invoiceNo,
                          cells: [
                            DataCell(Text(inv.invoiceNo)),
                            DataCell(Text(Fmt.date(inv.date))),
                            DataCell(Text(
                                inv.supplier.isEmpty ? '—' : inv.supplier)),
                            DataCell(Text(Fmt.money(inv.discount))),
                            DataCell(Text(Fmt.money(inv.subtotal))),
                            DataCell(Text(Fmt.money(inv.grandTotal),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700))),
                            DataCell(_viewButton(
                                () => provider.selectPurchase(inv))),
                          ],
                        ),
                    ],
                  ),
          ),
        ),
        if (data.returns.isNotEmpty && selected == null) ...[
          const SizedBox(height: 16),
          Expanded(
            flex: 2,
            child: SectionCard(
              title: 'Purchase Returns',
              fillHeight: true,
              child: ScrollableTable(
                flexColumn: 2,
                columns: const [
                  DataColumn(label: Text('Return No.')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Supplier')),
                  DataColumn(label: Text('Qty'), numeric: true),
                  DataColumn(label: Text('Value'), numeric: true),
                ],
                rows: [
                  for (final row in data.returns)
                    DataRow(cells: [
                      DataCell(Text(row.invoiceNo)),
                      DataCell(Text(Fmt.date(row.date))),
                      DataCell(Text(row.party.isEmpty ? '—' : row.party)),
                      DataCell(Text(_qty(row.quantity))),
                      DataCell(Text(Fmt.money(row.grandTotal),
                          style:
                              const TextStyle(fontWeight: FontWeight.w700))),
                    ]),
                ],
              ),
            ),
          ),
        ],
      ],
    );

    return _masterDetail(
      table: left,
      panel: selected == null
          ? null
          : _DetailPanel(
              title: selected.invoiceNo,
              subtitle: '${Fmt.date(selected.date)}  ·  '
                  '${selected.supplier.isEmpty ? "No supplier" : selected.supplier}',
              onClose: () => provider.selectPurchase(null),
              body: _ItemsTable(items: selected.items, rateHead: 'Cost'),
              totals: [
                ('Sub Total', selected.subtotal),
                ('Discount', selected.discount),
                if (selected.tax != 0) ('Tax', selected.tax),
                ('Total Amount', selected.grandTotal),
              ],
            ),
    );
  }
}

// ═══════════════════════════════ shared bits ════════════════════════════════

/// Right-hand detail panel chrome: header, a scrollable [body], and a totals
/// block.
class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.title,
    required this.subtitle,
    required this.onClose,
    required this.body,
    required this.totals,
    this.moneyTotals = true,
  });

  final String title;
  final String subtitle;
  final VoidCallback onClose;
  final Widget body;
  final List<(String, double)> totals;

  /// Format the totals as money (true) or as bare quantities (Stock report).
  final bool moneyTotals;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.outline)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Close',
                icon: const AppIcon(AppIcons.close),
                onPressed: onClose,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: body),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Column(
            children: [
              for (var i = 0; i < totals.length; i++) ...[
                if (i == totals.length - 1) const Divider(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(totals[i].$1,
                          style: TextStyle(
                              fontWeight: i == totals.length - 1
                                  ? FontWeight.w700
                                  : FontWeight.w500)),
                      Text(
                          moneyTotals
                              ? Fmt.money(totals[i].$2)
                              : _qty(totals[i].$2),
                          style: TextStyle(
                              fontWeight: i == totals.length - 1
                                  ? FontWeight.w800
                                  : FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Product line table used inside the sale / sale-return / purchase panels.
class _ItemsTable extends StatelessWidget {
  const _ItemsTable({required this.items, this.rateHead = 'Rate'});

  final List<LineReportRow> items;
  final String rateHead;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const EmptyState(
          icon: AppIcons.bar_chart_outlined, title: 'No items');
    }
    return ScrollableTable(
      flexColumn: -1, // narrow panel — let the table scroll, don't squeeze
      columnSpacing: 14,
      columns: [
        const DataColumn(label: Text('Product')),
        const DataColumn(label: Text('Qty'), numeric: true),
        DataColumn(label: Text(rateHead), numeric: true),
        const DataColumn(label: Text('Disc'), numeric: true),
        const DataColumn(label: Text('Amount'), numeric: true),
      ],
      rows: [
        for (final it in items)
          DataRow(cells: [
            DataCell(Text(it.product)),
            DataCell(Text('${_qty(it.quantity)} ${it.unit}')),
            DataCell(Text(Fmt.money(it.price))),
            DataCell(Text(it.discount == 0 ? '—' : Fmt.money(it.discount))),
            DataCell(Text(Fmt.money(it.lineTotal),
                style: const TextStyle(fontWeight: FontWeight.w700))),
          ]),
      ],
    );
  }
}

/// A small string-only table for the Profit & Loss / Category drill-downs.
class _MiniTable extends StatelessWidget {
  const _MiniTable({required this.columns, required this.rows});

  final List<String> columns;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const EmptyState(
          icon: AppIcons.bar_chart_outlined, title: 'Nothing to show');
    }
    return ScrollableTable(
      flexColumn: -1, // narrow panel — let the table scroll, don't squeeze
      columnSpacing: 14,
      columns: [
        for (var i = 0; i < columns.length; i++)
          DataColumn(label: Text(columns[i]), numeric: i == columns.length - 1),
      ],
      rows: [
        for (final r in rows)
          DataRow(cells: [
            for (var i = 0; i < r.length; i++)
              DataCell(Text(r[i],
                  style: i == r.length - 1
                      ? const TextStyle(fontWeight: FontWeight.w700)
                      : null)),
          ]),
      ],
    );
  }
}

/// Compact From / To date picker shown as a plain [AlertDialog]. Each field
/// opens a `showDatePicker`. Pops a [DateTimeRange] on Apply.
class _DateRangeDialog extends StatefulWidget {
  const _DateRangeDialog({required this.initial});

  final DateTimeRange initial;

  @override
  State<_DateRangeDialog> createState() => _DateRangeDialogState();
}

class _DateRangeDialogState extends State<_DateRangeDialog> {
  late DateTime _from = widget.initial.start;
  late DateTime _to = widget.initial.end;

  Future<void> _pick({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? _from : _to,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _from = picked;
        if (_to.isBefore(_from)) _to = _from;
      } else {
        _to = picked;
        if (_from.isAfter(_to)) _from = _to;
      }
    });
  }

  void _preset(DateTime from, DateTime to) => setState(() {
        _from = from;
        _to = to;
      });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return AlertDialog(
      title: const Text('Select date range'),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(label: 'From', value: _from, onTap: () => _pick(isFrom: true)),
            const SizedBox(height: 12),
            _field(label: 'To', value: _to, onTap: () => _pick(isFrom: false)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('Today'),
                  onPressed: () => _preset(today, today),
                ),
                ActionChip(
                  label: const Text('This month'),
                  onPressed: () =>
                      _preset(DateTime(now.year, now.month, 1), today),
                ),
                ActionChip(
                  label: const Text('Last 30 days'),
                  onPressed: () =>
                      _preset(today.subtract(const Duration(days: 29)), today),
                ),
                ActionChip(
                  label: const Text('This year'),
                  onPressed: () => _preset(DateTime(now.year, 1, 1), today),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
              context, DateTimeRange(start: _from, end: _to)),
          child: const Text('Apply'),
        ),
      ],
    );
  }

  Widget _field({
    required String label,
    required DateTime value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          border: const OutlineInputBorder(),
          prefixIcon: const Padding(
            padding: EdgeInsets.only(left: 8, right: 6),
            child: AppIcon(AppIcons.event, size: 15),
          ),
          prefixIconConstraints:
              const BoxConstraints(minWidth: 0, minHeight: 0),
        ),
        child: Text(Fmt.date(value)),
      ),
    );
  }
}
