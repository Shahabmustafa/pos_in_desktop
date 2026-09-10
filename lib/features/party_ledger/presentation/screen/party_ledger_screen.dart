import 'package:flutter/material.dart';
import 'package:pos/shared/app_icon.dart';

import '../../../../config/format.dart';
import '../../../../shared/export/export_button.dart';
import '../../../../shared/export/export_doc.dart';
import '../../../../shared/feature_ui.dart';
import '../../../../shared/searchable_dropdown.dart';
import '../../data/model/party_ledger_model.dart';
import '../provider/party_ledger_provider.dart';

/// Party Ledger — an account statement for one customer or one company:
/// opening balance, every document that moved it in the date range, a running
/// balance, and a closing figure.
class PartyLedgerScreen extends StatefulWidget {
  const PartyLedgerScreen({
    super.key,
    this.provider,
    this.initialKind,
    this.initialPartyId,
  });

  static const String routeName = '/party-ledger';

  final PartyLedgerProvider? provider;

  /// Opened from a Customer / Company row: preselect that party.
  final LedgerKind? initialKind;
  final int? initialPartyId;

  @override
  State<PartyLedgerScreen> createState() => _PartyLedgerScreenState();
}

class _PartyLedgerScreenState extends State<PartyLedgerScreen> {
  late final PartyLedgerProvider _provider =
      widget.provider ?? PartyLedgerProvider();

  @override
  void initState() {
    super.initState();
    if (widget.initialKind != null) {
      _provider.setKind(widget.initialKind!);
    }
    _provider.load(preselectId: widget.initialPartyId);
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

  ExportDoc? _exportDoc() {
    final l = _provider.ledger;
    if (l == null) return null;
    final range =
        '${Fmt.date(_provider.range.start)} to ${Fmt.date(_provider.range.end)}';
    final rows = <List<String>>[
      ['', 'Opening', '—', 'Brought forward', '', '', Fmt.money(l.opening)],
      for (final e in l.entries)
        [
          Fmt.date(e.date),
          e.type,
          e.docNo,
          e.detail,
          e.debit == 0 ? '' : Fmt.money(e.debit),
          e.credit == 0 ? '' : Fmt.money(e.credit),
          Fmt.money(e.runningBalance),
        ],
      [
        '',
        'Closing',
        '—',
        'Carried forward',
        Fmt.money(l.totalDebit),
        Fmt.money(l.totalCredit),
        Fmt.money(l.closing),
      ],
    ];
    return ExportDoc(
      title: '${_provider.kind.label} Ledger ${l.partyName} $range',
      subtitle: '${l.partyName}  ·  ${_provider.kind.label} ledger  ·  $range',
      tables: [
        ExportTable(
          columns: const [
            'Date', 'Type', 'Doc #', 'Detail', 'Debit', 'Credit', 'Balance'
          ],
          rows: rows,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Party Ledger'),
        actions: [
          ExportButton(
            enabled: !_provider.loading &&
                _provider.error == null &&
                _provider.ledger != null,
            builder: () => _exportDoc(),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const AppIcon(AppIcons.refresh),
            onPressed: () => _provider.load(),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListenableBuilder(
        listenable: _provider,
        builder: (context, _) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Toolbar(provider: _provider, onPickRange: _pickRange),
              const Divider(height: 1),
              Expanded(
                child: Builder(builder: (context) {
                  if (_provider.loading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (_provider.error != null) {
                    return ErrorState(
                        message: _provider.error!,
                        onRetry: () => _provider.load());
                  }
                  return Padding(
                    padding: const EdgeInsets.all(20),
                    child: _Body(provider: _provider),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({required this.provider, required this.onPickRange});

  final PartyLedgerProvider provider;
  final VoidCallback onPickRange;

  @override
  Widget build(BuildContext context) {
    final r = provider.range;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        children: [
          for (final k in LedgerKind.values) ...[
            ChoiceChip(
              label: Text(k.label),
              selected: provider.kind == k,
              onSelected: (_) => provider.setKind(k),
            ),
            const SizedBox(width: 8),
          ],
          const SizedBox(width: 8),
          SizedBox(
            width: 280,
            child: SearchableDropdown<int>(
              items: [for (final p in provider.parties) p.id],
              value: provider.party?.id,
              itemLabel: (id) => provider.parties
                  .firstWhere((p) => p.id == id,
                      orElse: () => const PartyRef(
                          id: -1, name: '', storedBalance: 0))
                  .name,
              hintText: 'Select ${provider.kind.label.toLowerCase()}',
              onChanged: (id) {
                if (id == null) {
                  provider.selectParty(null);
                  return;
                }
                for (final p in provider.parties) {
                  if (p.id == id) {
                    provider.selectParty(p);
                    return;
                  }
                }
              },
            ),
          ),
          const Spacer(),
          OutlinedButton.icon(
            onPressed: onPickRange,
            icon: const AppIcon(AppIcons.event, size: 16),
            label: Text('${Fmt.date(r.start)}  →  ${Fmt.date(r.end)}'),
          ),
        ],
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.provider});

  final PartyLedgerProvider provider;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ledger = provider.ledger;

    if (provider.party == null || ledger == null) {
      return EmptyState(
        icon: AppIcons.description_outlined,
        title: provider.parties.isEmpty
            ? 'No ${provider.kind.label.toLowerCase()} records yet'
            : 'Pick a ${provider.kind.label.toLowerCase()} to see its ledger',
      );
    }

    final owed = ledger.closing;
    final owedLabel = provider.kind == LedgerKind.customer
        ? (owed >= 0 ? 'Customer owes' : 'Advance / credit')
        : (owed >= 0 ? 'You owe' : 'Advance / credit');
    final closeTint = owed > 0
        ? const Color(0xFFC62828)
        : const Color(0xFF2E7D32);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StatCardRow(cards: [
          StatCard(title: 'Opening', subtitle: Fmt.money(ledger.opening)),
          StatCard(
              title: 'Debit',
              subtitle: Fmt.money(ledger.totalDebit),
              tint: const Color(0xFFC62828)),
          StatCard(
              title: 'Credit',
              subtitle: Fmt.money(ledger.totalCredit),
              tint: const Color(0xFF2E7D32)),
          StatCard(
              title: owedLabel,
              subtitle: Fmt.money(owed.abs()),
              tint: closeTint),
        ]),
        const SizedBox(height: 16),
        Expanded(
          child: SectionCard(
            title: ledger.partyName,
            subtitle:
                '${ledger.entries.length} movement(s)  ·  ${Fmt.date(provider.range.start)} → ${Fmt.date(provider.range.end)}',
            fillHeight: true,
            child: ScrollableTable(
              flexColumn: 3, // Detail
              columns: const [
                DataColumn(label: Text('Date')),
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('Doc #')),
                DataColumn(label: Text('Detail')),
                DataColumn(label: Text('Debit'), numeric: true),
                DataColumn(label: Text('Credit'), numeric: true),
                DataColumn(label: Text('Balance'), numeric: true),
              ],
              rows: [
                _plainRow(
                  cells: const ['', 'Opening', '—', 'Brought forward', '', ''],
                  balance: ledger.opening,
                  bold: true,
                  bg: scheme.surfaceContainerHighest,
                ),
                for (final e in ledger.entries)
                  DataRow(cells: [
                    DataCell(Text(Fmt.date(e.date))),
                    DataCell(Text(e.type)),
                    DataCell(Text(e.docNo)),
                    DataCell(Text(e.detail)),
                    DataCell(Text(e.debit == 0 ? '—' : Fmt.money(e.debit),
                        style: TextStyle(
                            color: e.debit == 0
                                ? null
                                : const Color(0xFFC62828)))),
                    DataCell(Text(e.credit == 0 ? '—' : Fmt.money(e.credit),
                        style: TextStyle(
                            color: e.credit == 0
                                ? null
                                : const Color(0xFF2E7D32)))),
                    DataCell(Text(Fmt.money(e.runningBalance),
                        style:
                            const TextStyle(fontWeight: FontWeight.w600))),
                  ]),
                _plainRow(
                  cells: [
                    '',
                    'Closing',
                    '—',
                    'Carried forward',
                    Fmt.money(ledger.totalDebit),
                    Fmt.money(ledger.totalCredit),
                  ],
                  balance: ledger.closing,
                  bold: true,
                  bg: scheme.surfaceContainerHighest,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// A summary row: 6 string cells + a formatted balance cell.
  DataRow _plainRow({
    required List<String> cells,
    required double balance,
    bool bold = false,
    Color? bg,
  }) {
    final style = bold ? const TextStyle(fontWeight: FontWeight.w700) : null;
    return DataRow(
      color: bg == null ? null : WidgetStatePropertyAll(bg),
      cells: [
        for (final c in cells) DataCell(Text(c, style: style)),
        DataCell(Text(Fmt.money(balance), style: style)),
      ],
    );
  }
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
                  label: const Text('This month'),
                  onPressed: () =>
                      _preset(DateTime(now.year, now.month, 1), today),
                ),
                ActionChip(
                  label: const Text('This year'),
                  onPressed: () => _preset(DateTime(now.year, 1, 1), today),
                ),
                ActionChip(
                  label: const Text('Last 12 months'),
                  onPressed: () => _preset(
                      DateTime(now.year - 1, now.month, now.day), today),
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
