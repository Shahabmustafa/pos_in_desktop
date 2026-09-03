/// Small formatting helpers shared across features.
class Fmt {
  const Fmt._();

  /// `1234567.5` -> `Rs 1,234,568` (no decimals) or `Rs 1,234,567.50` when [decimals] is true.
  static String money(num value, {bool decimals = false}) {
    final negative = value < 0;
    final abs = value.abs();
    final fixed = abs.toStringAsFixed(decimals ? 2 : 0);
    final parts = fixed.split('.');
    final intPart = parts[0];
    final buf = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
      buf.write(intPart[i]);
    }
    final grouped = parts.length > 1 ? '$buf.${parts[1]}' : buf.toString();
    return '${negative ? '-' : ''}Rs $grouped';
  }

  /// `DateTime` -> `2026-09-08`.
  static String date(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }
}
