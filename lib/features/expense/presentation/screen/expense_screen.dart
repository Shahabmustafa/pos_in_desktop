import 'package:flutter/material.dart';
import 'package:pos/shared/app_icon.dart';

import '../../../../config/format.dart';
import '../../../../shared/feature_ui.dart';
import '../../../../shared/searchable_dropdown.dart';
import '../../../login/data/permissions.dart';
import '../../../login/presentation/access_scope.dart';
import '../../data/model/expense_entry_model.dart';
import '../../data/model/expense_head_model.dart';
import '../provider/expense_provider.dart';
import '../widget/expense_entry_form_dialog.dart';
import '../widget/expense_head_form_dialog.dart';

/// Expense module: Expense Heads + Expense Entries.
class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key, this.provider});

  static const String routeName = '/expense';

  final ExpenseProvider? provider;

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  late final ExpenseProvider _provider = widget.provider ?? ExpenseProvider();

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

  Future<void> _headForm([ExpenseHeadModel? existing]) async {
    final result = await showDialog<ExpenseHeadModel>(
      context: context,
      builder: (_) => ExpenseHeadFormDialog(initial: existing),
    );
    if (result != null) await _provider.saveHead(result);
  }

  Future<void> _deleteHead(ExpenseHeadModel h) async {
    if (await _confirm('Delete expense head?',
        '"${h.name}" and all its entries will be removed.')) {
      await _provider.deleteHead(h.id!);
    }
  }

  Future<void> _entryForm([ExpenseEntryModel? existing]) async {
    if (_provider.heads.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add an expense head first')),
      );
      return;
    }
    final result = await showDialog<ExpenseEntryModel>(
      context: context,
      builder: (_) => ExpenseEntryFormDialog(
        heads: _provider.heads,
        initial: existing,
        presetHeadId: _provider.entryFilterHeadId,
      ),
    );
    if (result != null) await _provider.saveEntry(result);
  }

  Future<void> _deleteEntry(ExpenseEntryModel e) async {
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
    final canAdd = access.can('expense', PermAction.add);
    final canEdit = access.can('expense', PermAction.edit);
    final canDelete = access.can('expense', PermAction.delete);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Expense'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Expense Heads'),
              Tab(text: 'Expense Entries'),
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

  final ExpenseProvider provider;
  final VoidCallback? onAdd;
  final ValueChanged<ExpenseHeadModel>? onEdit;
  final ValueChanged<ExpenseHeadModel>? onDelete;

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
                title: 'Total expense',
                subtitle: Fmt.money(provider.grandTotal),
                tint: const Color(0xFFC62828),
              ),
              StatCard(
                title: 'Expense heads',
                subtitle: '${provider.heads.length}',
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
            child: SectionCard(
              title: 'Expense Heads',
              subtitle: 'Categories of spend',
              fillHeight: true,
              trailing: onAdd == null
                  ? null
                  : FilledButton.icon(
                      onPressed: onAdd,
                      icon: const AppIcon(AppIcons.add),
                      label: const Text('Add Expense Head'),
                    ),
              child: provider.heads.isEmpty
                  ? EmptyState(
                      icon: AppIcons.category_outlined,
                      title: 'No expense heads yet',
                      actionLabel: onAdd == null ? null : 'Add Expense Head',
                      onAction: onAdd,
                    )
                  : ScrollableTable(
                      flexColumn: 1, // Description
                      columns: const [
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Description')),
                        DataColumn(label: Text('Total Spent'), numeric: true),
                        DataColumn(label: Text('Active')),
                        DataColumn(label: Text('')),
                      ],
                      rows: [
                        for (final h in provider.heads)
                          DataRow(
                            onSelectChanged:
                                onEdit == null ? null : (_) => onEdit!(h),
                            cells: [
                              DataCell(Text(h.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600))),
                              DataCell(Text(h.description)),
                              DataCell(Text(
                                Fmt.money(provider.totalOf(h.id!),
                                    decimals: true),
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: scheme.primary,
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

  final ExpenseProvider provider;
  final VoidCallback? onAdd;
  final ValueChanged<ExpenseEntryModel>? onEdit;
  final ValueChanged<ExpenseEntryModel>? onDelete;

  @override
  Widget build(BuildContext context) {
    final cash = provider.entries
        .where((e) => e.paymentMode == ExpensePaymentMode.cash)
        .fold<double>(0, (a, e) => a + e.amount);
    final bank = provider.entries
        .where((e) => e.paymentMode == ExpensePaymentMode.bank)
        .fold<double>(0, (a, e) => a + e.amount);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
          child: StatCardRow(
            cards: [
              StatCard(
                title: 'Shown total',
                subtitle: Fmt.money(provider.entriesTotal),
              ),
              StatCard(
                title: 'Cash',
                subtitle: Fmt.money(cash),
                tint: const Color(0xFF00796B),
              ),
              StatCard(
                title: 'Bank',
                subtitle: Fmt.money(bank),
                tint: const Color(0xFF3949AB),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
            child: SectionCard(
              title: 'Expense Entries',
              subtitle: 'Recorded spends',
              fillHeight: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 210,
                    child: SearchableDropdown<int>(
                      items: [for (final h in provider.heads) h.id!],
                      value: provider.entryFilterHeadId,
                      itemLabel: (id) => provider.heads
                          .firstWhere((h) => h.id == id,
                              orElse: () => const ExpenseHeadModel(name: '—'))
                          .name,
                      hintText: 'Expense head',
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
                      label: const Text('Add Expense Entry'),
                    ),
                  ],
                ],
              ),
              child: provider.entries.isEmpty
                  ? EmptyState(
                      icon: AppIcons.payments_outlined,
                      title: 'No entries yet',
                      actionLabel: onAdd == null ? null : 'Add Expense Entry',
                      onAction: onAdd,
                    )
                  : ScrollableTable(
                      flexColumn: 4, // Description
                      columns: const [
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Expense Head')),
                        DataColumn(label: Text('Mode')),
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
                              DataCell(Text(e.expenseHeadName)),
                              DataCell(StatusPill(
                                text: e.paymentMode.label,
                                color: e.paymentMode == ExpensePaymentMode.bank
                                    ? Colors.indigo
                                    : Colors.teal,
                              )),
                              DataCell(Text(
                                Fmt.money(e.amount, decimals: true),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700),
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
