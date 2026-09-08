import 'package:flutter/material.dart';
import 'package:pos/shared/app_icon.dart';

import '../../../../config/format.dart';
import '../../../../shared/feature_ui.dart';
import '../../../../shared/searchable_dropdown.dart';
import '../../../login/data/permissions.dart';
import '../../../login/presentation/access_scope.dart';
import '../../data/model/voucher_model.dart';
import '../provider/voucher_provider.dart';
import '../widget/voucher_form_dialog.dart';

/// Voucher module: payment / receipt / journal vouchers.
class VoucherScreen extends StatefulWidget {
  const VoucherScreen({super.key, this.provider});

  static const String routeName = '/voucher';

  final VoucherProvider? provider;

  @override
  State<VoucherScreen> createState() => _VoucherScreenState();
}

class _VoucherScreenState extends State<VoucherScreen> {
  late final VoucherProvider _provider = widget.provider ?? VoucherProvider();

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

  Future<void> _openForm([VoucherModel? existing]) async {
    final result = await showDialog<VoucherModel>(
      context: context,
      builder: (_) => VoucherFormDialog(
        initial: existing,
        suggestNo: _provider.nextNumber,
      ),
    );
    if (result == null) return;
    final ok = await _provider.save(result);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.type.label} voucher saved')),
      );
    }
  }

  Future<void> _confirmDelete(VoucherModel v) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete voucher?'),
        content: Text(
            '${v.type.label} voucher "${v.voucherNo.isEmpty ? v.party : v.voucherNo}" '
            'will be permanently removed.'),
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
    if (yes == true) await _provider.delete(v.id!);
  }

  @override
  Widget build(BuildContext context) {
    final access = AccessScope.of(context);
    final canAdd = access.can('voucher', PermAction.add);
    final canEdit = access.can('voucher', PermAction.edit);
    final canDelete = access.can('voucher', PermAction.delete);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Voucher'),
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
            return ErrorState(message: _provider.error!, onRetry: _provider.load);
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                child: StatCardRow(
                  cards: [
                    StatCard(
                      title: 'Receipts',
                      subtitle: Fmt.money(_provider.totalReceipts),
                      tint: const Color(0xFF2E7D32),
                    ),
                    StatCard(
                      title: 'Payments',
                      subtitle: Fmt.money(_provider.totalPayments),
                      tint: const Color(0xFFC62828),
                    ),
                    StatCard(
                      title: 'Net cash',
                      subtitle: Fmt.money(_provider.netCash),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                  child: SectionCard(
                    title: 'Vouchers',
                    subtitle: 'Payments, receipts and journal entries',
                    fillHeight: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 190,
                          child: SearchableDropdown<VoucherType>(
                            items: VoucherType.values,
                            value: _provider.filterType,
                            itemLabel: (t) => t.label,
                            hintText: 'Type',
                            includeNull: true,
                            nullLabel: 'All types',
                            onChanged: _provider.filterByType,
                          ),
                        ),
                        if (canAdd) ...[
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: () => _openForm(),
                            icon: const AppIcon(AppIcons.add),
                            label: const Text('Add Voucher'),
                          ),
                        ],
                      ],
                    ),
                    child: _provider.items.isEmpty
                        ? EmptyState(
                            icon: AppIcons.description_outlined,
                            title: 'No vouchers yet',
                            actionLabel: canAdd ? 'Add Voucher' : null,
                            onAction: canAdd ? () => _openForm() : null,
                          )
                        : ScrollableTable(
                            flexColumn: 6, // Narration
                            columns: const [
                              DataColumn(label: Text('Voucher #')),
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Type')),
                              DataColumn(label: Text('Party')),
                              DataColumn(label: Text('Mode')),
                              DataColumn(label: Text('Amount'), numeric: true),
                              DataColumn(label: Text('Narration')),
                              DataColumn(label: Text('')),
                            ],
                            rows: [
                              for (final v in _provider.items)
                                DataRow(
                                  onSelectChanged:
                                      canEdit ? (_) => _openForm(v) : null,
                                  cells: [
                                    DataCell(Text(v.voucherNo,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600))),
                                    DataCell(Text(Fmt.date(v.date))),
                                    DataCell(StatusPill(
                                      text: v.type.label,
                                      color: switch (v.type) {
                                        VoucherType.receipt => Colors.green,
                                        VoucherType.payment => Colors.red,
                                        VoucherType.journal => Colors.blueGrey,
                                      },
                                    )),
                                    DataCell(Text(v.party)),
                                    DataCell(StatusPill(
                                      text: v.mode.label,
                                      color: v.mode == VoucherMode.bank
                                          ? Colors.indigo
                                          : Colors.teal,
                                    )),
                                    DataCell(Text(
                                      Fmt.money(v.amount, decimals: true),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                    )),
                                    DataCell(Text(v.narration)),
                                    DataCell(RowActions(
                                      onEdit:
                                          canEdit ? () => _openForm(v) : null,
                                      onDelete: canDelete
                                          ? () => _confirmDelete(v)
                                          : null,
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
        },
      ),
    );
  }
}
