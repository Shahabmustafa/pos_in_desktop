import 'package:flutter/material.dart';

import 'dashboard_data.dart';

/// A KPI tile that shows exactly two lines: a title and a subtitle (value).
class KpiCard extends StatelessWidget {
  const KpiCard({super.key, required this.data});

  final KpiData data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              data.label.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.outline,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              data.value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: data.tint,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
