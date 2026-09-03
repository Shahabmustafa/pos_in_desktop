import 'package:flutter/material.dart';
import 'package:pos/shared/app_icon.dart';
import 'package:flutter/services.dart';

/// Shared presentation pieces used across feature screens, so cards, toolbars,
/// tables and empty/error states look the same everywhere — matching the
/// Dashboard's card style. Blue accent throughout.

/// A wide summary card showing exactly two lines — a title and a subtitle.
/// It stretches to fill its slot; put several inside a [StatCardRow].
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.tint,
  });

  final String title;
  final String subtitle;
  final Color? tint;

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
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: scheme.outline,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: tint ?? scheme.primary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A row of [StatCard]s that share the width evenly and match in height.
class StatCardRow extends StatelessWidget {
  const StatCardRow({super.key, required this.cards});

  final List<StatCard> cards;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(child: cards[i]),
          ],
        ],
      ),
    );
  }
}

/// A titled panel with the same card style as the Dashboard.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.padding = const EdgeInsets.all(20),
    this.fillHeight = false,
  });

  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsets padding;

  /// When true the [child] expands to fill the card's height (for tables).
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title!,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: scheme.outline),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 16),
            ],
            if (fillHeight) Expanded(child: child) else child,
          ],
        ),
      ),
    );
  }
}

/// A DataTable that fills the width it is given (so it grows when the sidebar
/// collapses) and scrolls — horizontally only when the columns genuinely need
/// more room than is available, vertically when the rows overflow.
class ScrollableTable extends StatelessWidget {
  const ScrollableTable({
    super.key,
    required this.columns,
    required this.rows,
    this.columnSpacing = 24,
    this.flexColumn = 0,
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;
  final double columnSpacing;

  /// Index of the column that absorbs spare width so the table fills its slot.
  /// Set to a wide text column (description / address …) for the best look.
  final int flexColumn;

  List<DataColumn> get _sizedColumns => [
        for (var i = 0; i < columns.length; i++)
          if (i == flexColumn)
            DataColumn(
              label: columns[i].label,
              numeric: columns[i].numeric,
              tooltip: columns[i].tooltip,
              onSort: columns[i].onSort,
              columnWidth: const FlexColumnWidth(),
            )
          else
            columns[i],
      ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final table = DataTable(
          showCheckboxColumn: false,
          columnSpacing: columnSpacing,
          headingRowHeight: 44,
          dataRowMinHeight: 44,
          dataRowMaxHeight: 52,
          columns: _sizedColumns,
          rows: rows,
        );

        return Scrollbar(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Scrollbar(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                // The table is at least as wide as the available space, so it
                // stretches to fill; if its natural width is larger it grows
                // past this and the horizontal scroll bar takes over.
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: table,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A colored pill used for row status/type labels.
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.text, required this.color});

  final String text;
  final MaterialColor color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color.shade800,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Active / inactive tick.
class ActiveDot extends StatelessWidget {
  const ActiveDot({super.key, required this.active});
  final bool active;

  @override
  Widget build(BuildContext context) {
    return AppIcon(
      active ? AppIcons.check_circle : AppIcons.cancel,
      size: 18,
      color: active ? Colors.green.shade600 : Colors.grey.shade400,
    );
  }
}

/// Compact edit + delete buttons for a table row. Pass `null` for either
/// callback to hide that button (e.g. when the user lacks the permission).
class RowActions extends StatelessWidget {
  const RowActions({super.key, this.onEdit, this.onDelete});

  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onEdit != null)
          IconButton(
            tooltip: 'Edit',
            visualDensity: VisualDensity.compact,
            icon: const AppIcon(AppIcons.edit_outlined, size: 18),
            onPressed: onEdit,
          ),
        if (onDelete != null)
          IconButton(
            tooltip: 'Delete',
            visualDensity: VisualDensity.compact,
            icon: const AppIcon(AppIcons.delete_outline, size: 18),
            onPressed: onDelete,
          ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String icon;
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.4),
              shape: BoxShape.circle,
            ),
            child: AppIcon(icon, size: 34, color: scheme.primary),
          ),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onAction,
              icon: const AppIcon(AppIcons.add),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shown when a feature fails to load. If the message references a `.sql` file,
/// it renders as a friendly "database setup needed" card with a ready-to-copy
/// `psql` command; otherwise as a plain error.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sqlPath =
        RegExp(r'lib/[\w/]+\.sql').firstMatch(message)?.group(0);
    final isSetup = sqlPath != null;

    final title = isSetup ? 'Database setup needed' : 'Couldn\'t load this page';
    final body = isSetup
        ? 'This feature\'s tables are missing or the database user cannot create '
            'them. Run the setup script once, then retry.'
        : message;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: (isSetup ? scheme.primary : scheme.error)
                          .withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: AppIcon(
                      isSetup ? AppIcons.dns_outlined : AppIcons.error_outline,
                      size: 30,
                      color: isSetup ? scheme.primary : scheme.error,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(body,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant)),
                  if (isSetup) ...[
                    const SizedBox(height: 16),
                    _CommandBox(
                      command:
                          'psql -h localhost -U postgres -d pos -f $sqlPath',
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const AppIcon(AppIcons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CommandBox extends StatefulWidget {
  const _CommandBox({required this.command});
  final String command;

  @override
  State<_CommandBox> createState() => _CommandBoxState();
}

class _CommandBoxState extends State<_CommandBox> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              widget.command,
              maxLines: 3,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: _copied ? 'Copied' : 'Copy',
            visualDensity: VisualDensity.compact,
            icon: AppIcon(_copied ? AppIcons.check : AppIcons.copy, size: 18),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: widget.command));
              if (!mounted) return;
              setState(() => _copied = true);
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) setState(() => _copied = false);
              });
            },
          ),
        ],
      ),
    );
  }
}
