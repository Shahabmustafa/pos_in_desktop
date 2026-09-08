import 'package:flutter/material.dart';
import 'package:pos/shared/app_icon.dart';

import '../../../../config/format.dart';
import '../../../../shared/export/export_button.dart';
import '../../../../shared/export/export_doc.dart';
import '../../../../shared/feature_ui.dart';
import '../../../login/data/permissions.dart';
import '../../../login/presentation/access_scope.dart';
import '../../data/model/cash_register_model.dart';
import '../provider/cash_register_provider.dart';
import '../widget/cash_entry_form_dialog.dart';

/// Cash Register — the cash book for the money in the drawer. A headline
/// "Cash in Hand", the opening float, and every cash movement (auto from cash
/// sales / refunds / cash expenses / cash vouchers, plus hand-entered rows)
/// with a running balance.
class CashRegisterScreen extends StatefulWidget {
  const CashRegisterScreen({super.key, this.provider});

  static const String routeName = '/cash-register';

  final CashRegisterProvider? provider;

  @override
  State<CashRegisterScreen> createState() => _CashRegisterScreenState();
}

class _CashRegisterScreenState extends State<CashRegisterScreen> {
  late final CashRegisterProvider _provider =
      widget.provider ?? CashRegisterProvider();

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

  Future<void> _entryForm([CashEntry? existing]) async {
    final result = await showDialog<CashEntry>(
      context: context,
      builder: (_) => CashEntryFormDialog(initial: existing),
    );
    if (result != null) await _provider.saveEntry(result);
  }

  Future<void> _editOpening() async {
    final result = await showDialog<CashAccount>(
      context: context,
      builder: (_) => CashOpeningDialog(initial: _provider.account),
    );
    if (result != null) await _provider.saveAccount(result);
  }

  ExportDoc? _exportDoc() {
    final book = _provider.book;
    final range =
        '${Fmt.date(_provider.range.start)} to ${Fmt.date(_provider.range.end)}';
    final rows = <List<String>>[
      ['', 'Opening', '', 'Brought forward', '', '', Fmt.money(book.opening)],
      for (final m in book.entries)
        [
          Fmt.date(m.date),
          m.type,
          m.category,
          m.detail,
          m.inAmount == 0 ? '' : Fmt.money(m.inAmount),
          m.outAmount == 0 ? '' : Fmt.money(m.outAmount),
          Fmt.money(m.runningBalance),
        ],
      [
        '',
        'Closing',
        '',
        'Carried forward',
        Fmt.money(book.totalIn),
        Fmt.money(book.totalOut),
        Fmt.money(book.closing),
      ],
    ];
    return ExportDoc(
      title: 'Cash Register $range',
      subtitle: 'Cash book  ·  $range  ·  '
          'Cash in hand ${Fmt.money(book.cashInHand, decimals: true)}',
      tables: [
        ExportTable(
          columns: const [
            'Date', 'Type', 'Category', 'Detail', 'In', 'Out', 'Balance'
          ],
          rows: rows,
        ),
      ],
    );
  }

  Future<void> _deleteEntry(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete cash entry?'),
        content: const Text('This movement will be removed.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await _provider.deleteEntry(id);
  }

  @override
  Widget build(BuildContext context) {
    final access = AccessScope.of(context);
    final canAdd = access.can('cash_register', PermAction.add);
    final canEdit = access.can('cash_register', PermAction.edit);
    final canDelete = access.can('cash_register', PermAction.delete);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cash Register'),
        actions: [
          if (canEdit)
            TextButton.icon(
              onPressed: _editOpening,
              icon: const AppIcon(AppIcons.tune, size: 16),
              label: const Text('Opening'),
            ),
          ListenableBuilder(
            listenable: _provider,
            builder: (context, _) => ExportButton(
              enabled: !_provider.loading && _provider.error == null,
              builder: _exportDoc,
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
      floatingActionButton: canAdd
          ? FloatingActionButton.extended(
              onPressed: () => _entryForm(),
              icon: const AppIcon(AppIcons.add, color: Colors.white),
              label: const Text('Cash Entry'),
            )
          : null,
      body: ListenableBuilder(
        listenable: _provider,
        builder: (context, _) {
          if (_provider.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_provider.error != null) {
            return ErrorState(
                message: _provider.error!, onRetry: _provider.load);
          }

          final book = _provider.book;
          final now = book.cashInHand;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                child: StatCardRow(cards: [
                  StatCard(
                    title: 'Cash in Hand',
                    subtitle: Fmt.money(now, decimals: true),
                    tint: now < 0
                        ? const Color(0xFFC62828)
                        : const Color(0xFF2E7D32),
                  ),
                  StatCard(
                      title: 'Opening (${Fmt.date(_provider.range.start)})',
                      subtitle: Fmt.money(book.opening)),
                  StatCard(
                      title: 'Cash in',
                      subtitle: Fmt.money(book.totalIn),
                      tint: const Color(0xFF2E7D32)),
                  StatCard(
                      title: 'Cash out',
                      subtitle: Fmt.money(book.totalOut),
                      tint: const Color(0xFFC62828)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
                child: Row(
                  children: [
                    Text('Cash book',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: _pickRange,
                      icon: const AppIcon(AppIcons.event, size: 16),
                      label: Text(
                          '${Fmt.date(_provider.range.start)}  →  ${Fmt.date(_provider.range.end)}'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                  child: SectionCard(
                    fillHeight: true,
                    child: _CashTable(
                      book: book,
                      onEdit: canEdit ? _entryForm : null,
                      onDelete: canDelete ? _deleteEntry : null,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CashTable extends StatelessWidget {
  const _CashTable({required this.book, this.onEdit, this.onDelete});

  final CashBook book;
  final void Function(CashEntry)? onEdit;
  final void Function(int)? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shade = scheme.surfaceContainerHighest;

    if (book.entries.isEmpty) {
      return EmptyState(
        icon: AppIcons.point_of_sale_outlined,
        title: 'No cash movement in this date range',
        actionLabel: onEdit == null ? null : 'Add a cash entry',
        onAction: onEdit == null ? null : () => onEdit!(CashEntry(date: DateTime.now())),
      );
    }

    return ScrollableTable(
      flexColumn: 3, // Detail
      columns: const [
        DataColumn(label: Text('Date')),
        DataColumn(label: Text('Type')),
        DataColumn(label: Text('Category')),
        DataColumn(label: Text('Detail')),
        DataColumn(label: Text('In'), numeric: true),
        DataColumn(label: Text('Out'), numeric: true),
        DataColumn(label: Text('Balance'), numeric: true),
        DataColumn(label: Text('')),
      ],
      rows: [
        DataRow(
          color: WidgetStatePropertyAll(shade),
          cells: [
            const DataCell(Text('')),
            const DataCell(Text('Opening',
                style: TextStyle(fontWeight: FontWeight.w700))),
            const DataCell(Text('')),
            const DataCell(Text('Brought forward',
                style: TextStyle(fontWeight: FontWeight.w700))),
            const DataCell(Text('')),
            const DataCell(Text('')),
            DataCell(Text(Fmt.money(book.opening),
                style: const TextStyle(fontWeight: FontWeight.w700))),
            const DataCell(Text('')),
          ],
        ),
        for (final m in book.entries)
          DataRow(cells: [
            DataCell(Text(Fmt.date(m.date))),
            DataCell(Text(m.type)),
            DataCell(Text(m.category)),
            DataCell(Text(m.detail)),
            DataCell(Text(m.inAmount == 0 ? '—' : Fmt.money(m.inAmount),
                style: TextStyle(
                    color: m.inAmount == 0
                        ? null
                        : const Color(0xFF2E7D32)))),
            DataCell(Text(m.outAmount == 0 ? '—' : Fmt.money(m.outAmount),
                style: TextStyle(
                    color: m.outAmount == 0
                        ? null
                        : const Color(0xFFC62828)))),
            DataCell(Text(Fmt.money(m.runningBalance),
                style: const TextStyle(fontWeight: FontWeight.w600))),
            DataCell(m.isManual && (onEdit != null || onDelete != null)
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (onEdit != null)
                        IconButton(
                          tooltip: 'Edit',
                          visualDensity: VisualDensity.compact,
                          icon: const AppIcon(AppIcons.edit_outlined, size: 18),
                          onPressed: () => onEdit!(_toEntry(m)),
                        ),
                      if (onDelete != null)
                        IconButton(
                          tooltip: 'Delete',
                          visualDensity: VisualDensity.compact,
                          icon: const AppIcon(AppIcons.delete_outline, size: 18),
                          onPressed: () => onDelete!(m.manualId!),
                        ),
                    ],
                  )
                : const SizedBox.shrink()),
          ]),
        DataRow(
          color: WidgetStatePropertyAll(shade),
          cells: [
            const DataCell(Text('')),
            const DataCell(Text('Closing',
                style: TextStyle(fontWeight: FontWeight.w700))),
            const DataCell(Text('')),
            const DataCell(Text('Carried forward',
                style: TextStyle(fontWeight: FontWeight.w700))),
            DataCell(Text(Fmt.money(book.totalIn),
                style: const TextStyle(fontWeight: FontWeight.w700))),
            DataCell(Text(Fmt.money(book.totalOut),
                style: const TextStyle(fontWeight: FontWeight.w700))),
            DataCell(Text(Fmt.money(book.closing),
                style: const TextStyle(fontWeight: FontWeight.w800))),
            const DataCell(Text('')),
          ],
        ),
      ],
    );
  }

  CashEntry _toEntry(CashMovement m) => CashEntry(
        id: m.manualId,
        date: m.date,
        direction:
            m.inAmount > 0 ? CashDirection.cashIn : CashDirection.cashOut,
        amount: m.inAmount > 0 ? m.inAmount : m.outAmount,
        category: m.category == '—' ? '' : m.category,
        description: m.detail,
      );
}

/// Compact From / To date picker, mirrors the Reports screen dialog.
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
                  label: const Text('This year'),
                  onPressed: () => _preset(DateTime(now.year, 1, 1), today),
                ),
                ActionChip(
                  label: const Text('All time'),
                  onPressed: () => _preset(DateTime(2000, 1, 1), today),
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
          onPressed: () =>
              Navigator.pop(context, DateTimeRange(start: _from, end: _to)),
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
