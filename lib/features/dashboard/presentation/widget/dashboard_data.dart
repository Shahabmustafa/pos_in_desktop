import 'package:flutter/material.dart';

/// ---------------------------------------------------------------------------
/// View models for the Dashboard widgets. The screen builds these from the
/// live [DashboardSummary] it gets from [DashboardProvider].
/// ---------------------------------------------------------------------------

class KpiData {
  const KpiData({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
    this.trend,
  });

  final String label;
  final String value;
  final String icon;
  final Color tint;

  /// e.g. "72.5% of sales" — optional.
  final String? trend;
}

class MonthBar {
  const MonthBar(this.label, this.value);

  /// Day-of-month label, e.g. "1", "2", … "30".
  final String label;
  final double value;
}

class ProductSale {
  const ProductSale(this.name, this.qty, this.amount);
  final String name;
  final int qty;
  final double amount;
}
