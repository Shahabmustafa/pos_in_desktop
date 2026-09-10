import 'package:flutter/material.dart';
import 'package:pos/shared/app_icon.dart';

import '../../../../config/format.dart';
import '../../../../shared/feature_ui.dart';
import '../../data/model/dashboard_model.dart';
import '../provider/dashboard_provider.dart';
import '../widget/dashboard_bar_chart.dart';
import '../widget/dashboard_data.dart';
import '../widget/kpi_card.dart';
import '../widget/top_products_list.dart';

/// Dashboard module. Reads live figures from the database via
/// [DashboardProvider]: today's sales (split cash / credit), stock value,
/// today's expense, a 30-day sales bar chart and the month's most-sold
/// products.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.provider});

  static const String routeName = '/dashboard';

  final DashboardProvider? provider;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final DashboardProvider _provider = widget.provider ?? DashboardProvider();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
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
          return _DashboardBody(summary: _provider.summary);
        },
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final kpis = _kpisFor(summary);
    final bars = [
      for (final d in summary.dailySales) MonthBar('${d.date.day}', d.total),
    ];
    final products = [
      for (final p in summary.topProducts)
        ProductSale(p.name, p.quantity.round(), p.amount),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ---- KPI cards (single row) ------------------------------
              _KpiRow(kpis: kpis, available: constraints.maxWidth),
              const SizedBox(height: 24),

              // ---- Bar chart ------------------------------------------
              _Panel(
                title: 'Sales — last 30 days',
                subtitle: 'Daily sales value',
                child: SizedBox(
                  height: 280,
                  child: bars.isEmpty
                      ? const _PanelEmpty('No sales in the last 30 days')
                      : DashboardBarChart(bars: bars),
                ),
              ),
              const SizedBox(height: 24),

              // ---- Top products -------------------------------------
              _Panel(
                title: 'Most sold products',
                subtitle: 'Top 20 by quantity — this month',
                child: products.isEmpty
                    ? const _PanelEmpty('No sales recorded this month')
                    : TopProductsList(products: products),
              ),
            ],
          ),
        );
      },
    );
  }

  static List<KpiData> _kpisFor(DashboardSummary s) {
    final total = s.creditSale + s.cashSale;
    String share(double part) =>
        total > 0 ? '${(part / total * 100).toStringAsFixed(1)}% of sales' : '—';

    return [
      KpiData(
        label: 'Total Sale',
        value: Fmt.money(s.totalSale),
        icon: AppIcons.trending_up,
        tint: const Color(0xFF2196F3),
        trend: 'Today',
      ),
      KpiData(
        label: 'Total Stock',
        value: Fmt.money(s.totalStockValue),
        icon: AppIcons.inventory_2_outlined,
        tint: const Color(0xFF6A1B9A),
        trend: '${s.stockItemCount} items',
      ),
      KpiData(
        label: 'Total Expense',
        value: Fmt.money(s.totalExpense),
        icon: AppIcons.payments_outlined,
        tint: const Color(0xFFC62828),
        trend: 'Today',
      ),
      KpiData(
        label: 'Total Credit Sale',
        value: Fmt.money(s.creditSale),
        icon: AppIcons.account_balance_wallet_outlined,
        tint: const Color(0xFFEF6C00),
        trend: share(s.creditSale),
      ),
      KpiData(
        label: 'Total Cash Sale',
        value: Fmt.money(s.cashSale),
        icon: AppIcons.point_of_sale_outlined,
        tint: const Color(0xFF2E7D32),
        trend: share(s.cashSale),
      ),
    ];
  }
}

/// The five KPI cards, always on one row. Scrolls sideways if the window is
/// too narrow to fit them all.
class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.kpis, required this.available});

  final List<KpiData> kpis;
  final double available;

  static const double _minCardWidth = 200;
  static const double _gap = 16;

  @override
  Widget build(BuildContext context) {
    final count = kpis.length;
    final fitWidth = (available - _gap * (count - 1)) / count;

    // Wide enough: stretch all five across the row, equal height.
    if (fitWidth >= _minCardWidth) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const SizedBox(width: _gap),
              Expanded(child: KpiCard(data: kpis[i])),
            ],
          ],
        ),
      );
    }

    // Narrow: keep one row but let it scroll sideways.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < count; i++) ...[
              if (i > 0) const SizedBox(width: _gap),
              SizedBox(
                width: _minCardWidth,
                child: KpiCard(data: kpis[i]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.outline),
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _PanelEmpty extends StatelessWidget {
  const _PanelEmpty(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Text(
        message,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: scheme.outline),
      ),
    );
  }
}
