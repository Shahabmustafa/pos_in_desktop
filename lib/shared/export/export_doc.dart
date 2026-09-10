/// A format-neutral description of what a screen wants to export: a title and
/// one or more labelled tables. The [Exporter] turns this into CSV / Excel /
/// PDF / a print job / clipboard text.
library;

/// One table block inside an [ExportDoc]. Cells are already formatted strings
/// (money, dates, "—"); the exporter re-parses numbers where a format needs
/// them (Excel columns, for example).
class ExportTable {
  const ExportTable({
    required this.columns,
    required this.rows,
    this.heading,
  });

  /// Shown above the table in PDF / Excel; ignored by CSV apart from a blank
  /// separator line.
  final String? heading;
  final List<String> columns;
  final List<List<String>> rows;
}

/// The whole export payload for one screen action.
class ExportDoc {
  const ExportDoc({
    required this.title,
    required this.tables,
    this.subtitle,
  });

  /// Used for the file name, the Excel sheet name, and the PDF heading.
  final String title;

  /// A line under the title in PDF (e.g. the date range).
  final String? subtitle;

  final List<ExportTable> tables;

  /// A file-system-safe base name derived from [title].
  String get fileBase {
    final cleaned = title
        .replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
    return cleaned.isEmpty ? 'export' : cleaned;
  }
}
