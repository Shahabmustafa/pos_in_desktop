import 'package:flutter/material.dart';
import 'package:pos/shared/app_icon.dart';

import 'export_doc.dart';
import 'exporter.dart';

/// App-bar action that offers the export formats. Give it a [builder] that
/// snapshots the screen's current data into an [ExportDoc] when a format is
/// chosen.
class ExportButton extends StatelessWidget {
  const ExportButton({super.key, required this.builder, this.enabled = true});

  /// Called when a format is picked — return the data to export, or `null` to
  /// abort (e.g. nothing on screen yet).
  final ExportDoc? Function() builder;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ExportFormat>(
      tooltip: 'Export',
      enabled: enabled,
      icon: const AppIcon(AppIcons.download),
      position: PopupMenuPosition.under,
      onSelected: (fmt) {
        final doc = builder();
        if (doc == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nothing to export yet')),
          );
          return;
        }
        Exporter.run(context, doc, fmt);
      },
      itemBuilder: (context) => [
        for (final f in ExportFormat.values) ...[
          if (f == ExportFormat.clipboard) const PopupMenuDivider(),
          PopupMenuItem<ExportFormat>(
            value: f,
            child: Row(
              children: [
                AppIcon(f.icon, size: 18),
                const SizedBox(width: 12),
                Text(f.label),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
