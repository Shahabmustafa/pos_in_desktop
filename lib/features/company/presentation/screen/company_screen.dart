import 'package:flutter/material.dart';
import 'package:pos/shared/app_icon.dart';

import '../../../../config/format.dart';
import '../../../../shared/feature_ui.dart';
import '../../../login/data/permissions.dart';
import '../../../login/presentation/access_scope.dart';
import '../../../party_ledger/data/model/party_ledger_model.dart';
import '../../../party_ledger/presentation/screen/party_ledger_screen.dart';
import '../../data/model/company_model.dart';
import '../provider/company_provider.dart';
import '../widget/company_form_dialog.dart';

/// Company module: list + add / edit / delete.
class CompanyScreen extends StatefulWidget {
  const CompanyScreen({super.key, this.provider});

  static const String routeName = '/company';

  final CompanyProvider? provider;

  @override
  State<CompanyScreen> createState() => _CompanyScreenState();
}

class _CompanyScreenState extends State<CompanyScreen> {
  late final CompanyProvider _provider = widget.provider ?? CompanyProvider();

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

  Future<void> _openForm([CompanyModel? existing]) async {
    final result = await showDialog<CompanyModel>(
      context: context,
      builder: (_) => CompanyFormDialog(initial: existing),
    );
    if (result == null) return;
    final ok = await _provider.save(result);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Company "${result.name}" saved')),
      );
    }
  }

  Future<void> _confirmDelete(CompanyModel c) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete company?'),
        content: Text('"${c.name}" will be permanently removed.'),
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
    if (yes == true) await _provider.delete(c.id!);
  }

  @override
  Widget build(BuildContext context) {
    final access = AccessScope.of(context);
    final canAdd = access.can('company', PermAction.add);
    final canEdit = access.can('company', PermAction.edit);
    final canDelete = access.can('company', PermAction.delete);
    final canLedger = access.can('party_ledger', PermAction.view);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Companies'),
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

          final balance =
              _provider.items.fold<double>(0, (a, c) => a + c.openingBalance);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                child: StatCardRow(
                  cards: [
                    StatCard(
                      title: 'Companies',
                      subtitle: '${_provider.items.length}',
                    ),
                    StatCard(
                      title: 'Opening balance',
                      subtitle: Fmt.money(balance),
                      tint: const Color(0xFFEF6C00),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                  child: SectionCard(
                    title: 'Companies',
                    subtitle: 'Suppliers and vendors',
                    fillHeight: true,
                    trailing: canAdd
                        ? FilledButton.icon(
                            onPressed: () => _openForm(),
                            icon: const AppIcon(AppIcons.add),
                            label: const Text('Add Company'),
                          )
                        : null,
                    child: _provider.items.isEmpty
                        ? EmptyState(
                            icon: AppIcons.business_outlined,
                            title: 'No companies yet',
                            actionLabel:
                                canAdd ? 'Add your first company' : null,
                            onAction: canAdd ? () => _openForm() : null,
                          )
                        : ScrollableTable(
                            flexColumn: 3, // Address
                            columns: const [
                              DataColumn(label: Text('Name')),
                              DataColumn(label: Text('Email')),
                              DataColumn(label: Text('Phone')),
                              DataColumn(label: Text('Address')),
                              DataColumn(
                                  label: Text('Opening Balance'),
                                  numeric: true),
                              DataColumn(label: Text('Active')),
                              DataColumn(label: Text('')),
                            ],
                            rows: [
                              for (final c in _provider.items)
                                DataRow(
                                  onSelectChanged:
                                      canEdit ? (_) => _openForm(c) : null,
                                  cells: [
                                    DataCell(Text(c.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600))),
                                    DataCell(Text(c.email)),
                                    DataCell(Text(c.phone)),
                                    DataCell(Text(c.address)),
                                    DataCell(Text(Fmt.money(c.openingBalance,
                                        decimals: true))),
                                    DataCell(ActiveDot(active: c.isActive)),
                                    DataCell(Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (canLedger && c.id != null)
                                          IconButton(
                                            tooltip: 'Ledger',
                                            visualDensity: VisualDensity.compact,
                                            icon: const AppIcon(
                                                AppIcons.receipt_long_outlined,
                                                size: 18),
                                            onPressed: () => Navigator.of(context)
                                                .push(MaterialPageRoute(
                                              builder: (_) => PartyLedgerScreen(
                                                initialKind: LedgerKind.company,
                                                initialPartyId: c.id,
                                              ),
                                            )),
                                          ),
                                        RowActions(
                                          onEdit: canEdit
                                              ? () => _openForm(c)
                                              : null,
                                          onDelete: canDelete
                                              ? () => _confirmDelete(c)
                                              : null,
                                        ),
                                      ],
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
