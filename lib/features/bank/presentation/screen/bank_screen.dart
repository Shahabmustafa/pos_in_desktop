import 'package:flutter/material.dart';
import 'package:pos/shared/app_icon.dart';

import '../../../../config/format.dart';
import '../../../../shared/feature_ui.dart';
import '../../../../shared/searchable_dropdown.dart';
import '../../../login/data/permissions.dart';
import '../../../login/presentation/access_scope.dart';
import '../../data/model/bank_entry_model.dart';
import '../../data/model/bank_head_model.dart';
import '../provider/bank_provider.dart';
import '../widget/bank_entry_form_dialog.dart';
import '../widget/bank_head_form_dialog.dart';

/// Bank module: Bank Heads + Bank Entries.
class BankScreen extends StatefulWidget {
  const BankScreen({super.key, this.provider});

  static const String routeName = '/bank';

  final BankProvider? provider;

  @override
  State<BankScreen> createState() => _BankScreenState();
}

class _BankScreenState extends State<BankScreen> {
  late final BankProvider _provider = widget.provider ?? BankProvider();

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

  Future<void> _headForm([BankHeadModel? existing]) async {
    final result = await showDialog<BankHeadModel>(
      context: context,
      builder: (_) => BankHeadFormDialog(initial: existing),
    );
    if (result != null) await _provider.saveHead(result);
  }

  Future<void> _deleteHead(BankHeadModel h) async {
    if (await _confirm('Delete bank head?',
        '"${h.title}" and all its entries will be removed.')) {
      await _provider.deleteHead(h.id!);
    }
  }

  Future<void> _entryForm([BankEntryModel? existing]) async {
    if (_provider.heads.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a bank head first')),
      );
      return;
    }
    final result = await showDialog<BankEntryModel>(
      context: context,
      builder: (_) => BankEntryFormDialog(
        heads: _provider.heads,
        initial: existing,
        presetHeadId: _provider.entryFilterHeadId,
      ),
    );
    if (result != null) await _provider.saveEntry(result);
  }

  Future<void> _deleteEntry(BankEntryModel e) async {
    if (await _confirm('Delete entry?', 'This entry will be removed.')) {
      await _provider.deleteEntry(e.id!);
    }
  }

  Future<bool> _confirm(String title, String body) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
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
    return r ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final access = AccessScope.of(context);
    final canAdd = access.can('bank', PermAction.add);
    final canEdit = access.can('bank', PermAction.edit);
    final canDelete = access.can('bank', PermAction.delete);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bank'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Bank Heads'),
              Tab(text: 'Bank Entries'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Refresh',
              icon: const AppIcon(AppIcons.refresh),
              onPressed: _provider.load,
            ),
            const SizedBox(width: 12),
          ],
        ),
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
            return TabBarView(
              children: [
                _HeadsTab(
                  provider: _provider,
                  onAdd: canAdd ? () => _headForm() : null,
                  onEdit: canEdit ? _headForm : null,
                  onDelete: canDelete ? _deleteHead : null,
                ),
                _EntriesTab(
                  provider: _provider,
                  onAdd: canAdd ? () => _entryForm() : null,
                  onEdit: canEdit ? _entryForm : null,
                  onDelete: canDelete ? _deleteEntry : null,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _HeadsTab extends StatelessWidget {
  const _HeadsTab({
    required this.provider,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final BankProvider provider;
  final VoidCallback? onAdd;
  final ValueChanged<BankHeadModel>? onEdit;
  final ValueChanged<BankHeadModel>? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
          child: StatCardRow(
            cards: [
              StatCard(
                title: 'Total balance',
                subtitle: Fmt.money(provider.totalBalance),
              ),
              StatCard(
                title: 'Bank accounts',
                subtitle: '${provider.heads.length}',
                tint: const Color(0xFF6A1B9A),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
            child: SectionCard(
              title: 'Bank Heads',
              subtitle: 'Accounts the business owns',
              fillHeight: true,
              trailing: onAdd == null
                  ? null
                  : FilledButton.icon(
                      onPressed: onAdd,
                      icon: const AppIcon(AppIcons.add),
                      label: const Text('Add Bank Head'),
                    ),
              child: provider.heads.isEmpty
                  ? EmptyState(
                      icon: AppIcons.account_balance_outlined,
                      title: 'No bank heads yet',
                      actionLabel: onAdd == null ? null : 'Add Bank Head',
                      onAction: onAdd,
                    )
                  : ScrollableTable(
                      columns: const [
                        DataColumn(label: Text('Title')),
                        DataColumn(label: Text('Bank')),
                        DataColumn(label: Text('Account #')),
                        DataColumn(label: Text('Opening'), numeric: true),
                        DataColumn(label: Text('Balance'), numeric: true),
                        DataColumn(label: Text('Active')),
                        DataColumn(label: Text('')),
                      ],
                      rows: [
                        for (final h in provider.heads)
                          DataRow(
                            onSelectChanged:
                                onEdit == null ? null : (_) => onEdit!(h),
                            cells: [
                              DataCell(Text(h.title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600))),
                              DataCell(Text(h.bankName)),
                              DataCell(Text(h.accountNumber)),
                              DataCell(Text(Fmt.money(h.openingBalance,
                                  decimals: true))),
                              DataCell(Text(
                                Fmt.money(provider.balanceOf(h.id!),
                                    decimals: true),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: provider.balanceOf(h.id!) < 0
                                      ? scheme.error
                                      : scheme.primary,
                                ),
                              )),
                              DataCell(ActiveDot(active: h.isActive)),
                              DataCell(RowActions(
                                onEdit:
                                    onEdit == null ? null : () => onEdit!(h),
                                onDelete: onDelete == null
                                    ? null
                                    : () => onDelete!(h),
                              )),
                            ],
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------

class _EntriesTab extends StatelessWidget {
  const _EntriesTab({
    required this.provider,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final BankProvider provider;
  final VoidCallback? onAdd;
  final ValueChanged<BankEntryModel>? onEdit;
  final ValueChanged<BankEntryModel>? onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final deposits = provider.entries
        .where((e) => e.type == BankEntryType.deposit)
        .fold<double>(0, (a, e) => a + e.amount);
    final withdrawals = provider.entries
        .where((e) => e.type == BankEntryType.withdraw)
        .fold<double>(0, (a, e) => a + e.amount);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
          child: StatCardRow(
            cards: [
              StatCard(
                title: 'Deposits',
                subtitle: Fmt.money(deposits),
                tint: const Color(0xFF2E7D32),
              ),
              StatCard(
                title: 'Withdrawals',
                subtitle: Fmt.money(withdrawals),
                tint: const Color(0xFFC62828),
              ),
              StatCard(
                title: 'Net',
                subtitle: Fmt.money(deposits - withdrawals),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
            child: SectionCard(
              title: 'Bank Entries',
              subtitle: 'Deposits and withdrawals',
              fillHeight: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 210,
                    child: SearchableDropdown<int>(
                      items: [for (final h in provider.heads) h.id!],
                      value: provider.entryFilterHeadId,
                      itemLabel: (id) => provider.headTitle(id),
                      hintText: 'Bank head',
                      includeNull: true,
                      nullLabel: 'All heads',
                      onChanged: provider.filterEntriesByHead,
                    ),
                  ),
                  if (onAdd != null) ...[
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: onAdd,
                      icon: const AppIcon(AppIcons.add),
                      label: const Text('Add Bank Entry'),
                    ),
                  ],
                ],
              ),
              child: provider.entries.isEmpty
                  ? EmptyState(
                      icon: AppIcons.receipt_long_outlined,
                      title: 'No entries yet',
                      actionLabel: onAdd == null ? null : 'Add Bank Entry',
                      onAction: onAdd,
                    )
                  : ScrollableTable(
                      flexColumn: 4, // Description
                      columns: const [
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Bank Head')),
                        DataColumn(label: Text('Type')),
                        DataColumn(label: Text('Amount'), numeric: true),
                        DataColumn(label: Text('Description')),
                        DataColumn(label: Text('')),
                      ],
                      rows: [
                        for (final e in provider.entries)
                          DataRow(
                            onSelectChanged:
                                onEdit == null ? null : (_) => onEdit!(e),
                            cells: [
                              DataCell(Text(Fmt.date(e.date))),
                              DataCell(Text(e.bankHeadTitle)),
                              DataCell(StatusPill(
                                text: e.type.label,
                                color: e.type == BankEntryType.deposit
                                    ? Colors.green
                                    : Colors.red,
                              )),
                              DataCell(Text(
                                Fmt.money(e.amount, decimals: true),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: e.type == BankEntryType.withdraw
                                      ? scheme.error
                                      : Colors.green.shade700,
                                ),
                              )),
                              DataCell(Text(e.description)),
                              DataCell(RowActions(
                                onEdit:
                                    onEdit == null ? null : () => onEdit!(e),
                                onDelete: onDelete == null
                                    ? null
                                    : () => onDelete!(e),
                              )),
                            ],
                          ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
