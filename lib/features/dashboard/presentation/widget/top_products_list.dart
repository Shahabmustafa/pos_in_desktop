import 'package:flutter/material.dart';

import 'dashboard_data.dart';

/// Ranked list of the top-selling products with a relative-quantity bar.
class TopProductsList extends StatelessWidget {
  const TopProductsList({super.key, required this.products});

  final List<ProductSale> products;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxQty = products.isEmpty
        ? 1
        : products.map((p) => p.qty).reduce((a, b) => a > b ? a : b);

    return Column(
      children: [
        // header
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
          child: Row(
            children: [
              const SizedBox(width: 34),
              Expanded(
                flex: 5,
                child: Text('Product', style: _head(context)),
              ),
              Expanded(
                flex: 4,
                child: Text('Qty sold', style: _head(context)),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Amount',
                  textAlign: TextAlign.right,
                  style: _head(context),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        for (var i = 0; i < products.length; i++)
          _Row(
            rank: i + 1,
            product: products[i],
            qtyFraction: products[i].qty / maxQty,
            barColor: scheme.primary,
          ),
      ],
    );
  }

  TextStyle? _head(BuildContext context) => Theme.of(context)
      .textTheme
      .labelSmall
      ?.copyWith(
        color: Theme.of(context).colorScheme.outline,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
      );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.rank,
    required this.product,
    required this.qtyFraction,
    required this.barColor,
  });

  final int rank;
  final ProductSale product;
  final double qtyFraction;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 34,
            child: Text(
              '$rank',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: rank <= 3 ? scheme.primary : scheme.outline,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 4,
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text('${product.qty}'),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: qtyFraction,
                      minHeight: 6,
                      backgroundColor: scheme.surfaceContainerHighest,
                      color: barColor,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              _money(product.amount),
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  static String _money(double v) {
    final s = v.toStringAsFixed(0);
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return 'Rs $buf';
  }
}
