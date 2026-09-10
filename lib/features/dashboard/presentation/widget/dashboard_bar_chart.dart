import 'package:flutter/material.dart';

import 'dashboard_data.dart';

/// A lightweight single-series bar chart: recessive gridlines, thin bars with
/// rounded tops anchored to the baseline. Value labels sit above each bar only
/// when the bars are few enough to read; otherwise the x-axis labels thin out.
class DashboardBarChart extends StatelessWidget {
  const DashboardBarChart({super.key, required this.bars});

  final List<MonthBar> bars;

  static const int _ticks = 4;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxValue = _niceCeil(
      bars.map((b) => b.value).fold<double>(0, (a, b) => a > b ? a : b),
    );

    final dense = bars.length > 14;
    final showValueLabels = !dense;
    // With many bars, label roughly every 5th tick and always the last.
    final labelEvery = dense ? 5 : 1;
    final barPadding = dense ? 1.5 : 6.0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _YAxis(maxValue: maxValue, ticks: _ticks),
        const SizedBox(width: 8),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) {
              const labelStripHeight = 22.0;
              final plotHeight = c.maxHeight - labelStripHeight;
              return Column(
                children: [
                  SizedBox(
                    height: plotHeight,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: Column(
                            children: [
                              for (var i = 0; i < _ticks; i++)
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: Divider(
                                      height: 1,
                                      color: scheme.outlineVariant,
                                    ),
                                  ),
                                ),
                              Divider(height: 1, color: scheme.outline),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              for (final b in bars)
                                Expanded(
                                  child: _Bar(
                                    fraction: maxValue == 0
                                        ? 0
                                        : b.value / maxValue,
                                    color: scheme.primary,
                                    label: showValueLabels ? _short(b.value) : null,
                                    horizontalPadding: barPadding,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: labelStripHeight,
                    child: Row(
                      children: [
                        for (var i = 0; i < bars.length; i++)
                          Expanded(
                            child: Center(
                              child: (i % labelEvery == 0 ||
                                      i == bars.length - 1)
                                  ? Text(
                                      bars[i].label,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(color: scheme.outline),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  static double _niceCeil(double v) {
    if (v <= 0) return 1;
    final mag = _pow10(v.floor().toString().length - 1);
    return (v / mag).ceilToDouble() * mag;
  }

  static double _pow10(int n) {
    var r = 1.0;
    for (var i = 0; i < n; i++) {
      r *= 10;
    }
    return r;
  }

  static String _short(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }
}

class _YAxis extends StatelessWidget {
  const _YAxis({required this.maxValue, required this.ticks});

  final double maxValue;
  final int ticks;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style =
        Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.outline);
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = ticks; i >= 0; i--)
            Expanded(
              child: Align(
                alignment: i == ticks
                    ? Alignment.topRight
                    : (i == 0 ? Alignment.bottomRight : Alignment.centerRight),
                child: Text(
                  DashboardBarChart._short(maxValue * i / ticks),
                  style: style,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.fraction,
    required this.color,
    required this.label,
    required this.horizontalPadding,
  });

  final double fraction;
  final Color color;
  final String? label;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: LayoutBuilder(
        builder: (context, c) {
          final h = (c.maxHeight * fraction).clamp(2.0, c.maxHeight);
          return Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (label != null) ...[
                Text(
                  label!,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
              ],
              Container(
                height: h,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
