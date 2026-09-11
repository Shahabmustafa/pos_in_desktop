import 'package:flutter/material.dart';
import 'package:pos/shared/app_icon.dart';

import '../../../../config/format.dart';
import '../../../../shared/feature_ui.dart';
import '../../../login/data/permissions.dart';
import '../../../login/presentation/access_scope.dart';
import '../../data/model/company_payment_model.dart';
import '../provider/company_payment_provider.dart';
import '../widget/company_payment_form_dialog.dart';

/// Company Payment module: money paid to a company (supplier) against what
/// the business owes them, independent of any particular purchase invoice.
class CompanyPaymentScreen extends StatefulWidget {
  const CompanyPaymentScreen({super.key, this.provider});

  static const String routeName = '/company_payment';

  final CompanyPaymentProvider? provider;

  @override
  State<CompanyPaymentScreen> createState() => _CompanyPaymentScreenState();
}

class _CompanyPaymentScreenState extends State<CompanyPaymentScreen> {
  late final CompanyPaymentProvider _provider =
      widget.provider ?? CompanyPaymentProvider();

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

  Future<void> _openForm([CompanyPaymentModel? existing]) async {
    final result = await showDialog<CompanyPaymentModel>(
      context: context,
      builder: (_) => CompanyPaymentFormDialog(
        initial: existing,
        companies: _provider.companies,
        banks: _provider.banks,
        suggestNo: _provider.nextNumber,
      ),
    );
    if (result == null) return;
    final ok = await _provider.save(result);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment recorded')),
      );
    }
  }

  Future<void> _confirmDelete(CompanyPaymentModel p) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete payment?'),
        content: Text(
            'Payment "${p.paymentNo.isEmpty ? p.companyName : p.paymentNo}" '
            'will be removed and added back to what is owed to the company.'),
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
    if (yes == true) await _provider.delete(p.id!);
  }

  @override
  Widget build(BuildContext context) {
    final access = AccessScope.of(context);
    final canAdd = access.can('company_payment', PermAction.add);
    final canEdit = access.can('company_payment', PermAction.edit);
    final canDelete = access.can('company_payment', PermAction.delete);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pay Company'),
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

          final payableCompanies =
              _provider.companies.where((c) => c.payable > 0).length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                child: StatCardRow(
                  cards: [
                    StatCard(
                      title: 'Total paid',
                      subtitle: Fmt.money(_provider.totalPaid),
                      tint: const Color(0xFFC62828),
                    ),
                    StatCard(
                      title: 'Companies owed',
                      subtitle: '$payableCompanies',
                      tint: const Color(0xFF2E7D32),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 6, 8, 20),
                  child: SectionCard(
                    padding: const EdgeInsets.fromLTRB(12, 20, 12, 20),
                    title: 'Payments',
                    subtitle: 'Amounts paid to companies against what they are owed',
                    fillHeight: true,
                    trailing: canAdd
                        ? FilledButton.icon(
                            onPressed: () => _openForm(),
                            icon: const AppIcon(AppIcons.add),
                            label: const Text('Pay Company'),
                          )
                        : null,
                    child: _provider.items.isEmpty
                        ? EmptyState(
                            icon: AppIcons.payments_outlined,
                            title: 'No payments recorded yet',
                            actionLabel: canAdd ? 'Pay Company' : null,
                            onAction: canAdd ? () => _openForm() : null,
                          )
                        : ScrollableTable(
                            flexColumn: 5, // Narration
                            columns: const [
                              DataColumn(label: Text('Payment #')),
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Company')),
                              DataColumn(label: Text('Mode')),
                              DataColumn(label: Text('Amount'), numeric: true),
                              DataColumn(label: Text('Narration')),
                              DataColumn(label: Text('')),
                            ],
                            rows: [
                              for (final p in _provider.items)
                                DataRow(
                                  onSelectChanged:
                                      canEdit ? (_) => _openForm(p) : null,
                                  cells: [
                                    DataCell(Text(p.paymentNo,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600))),
                                    DataCell(Text(Fmt.date(p.date))),
                                    DataCell(Text(p.companyName)),
                                    DataCell(StatusPill(
                                      text: p.bankHeadId == null ? 'Cash' : 'Bank',
                                      color: p.bankHeadId == null
                                          ? Colors.teal
                                          : Colors.indigo,
                                    )),
                                    DataCell(Text(
                                      Fmt.money(p.amount, decimals: true),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700),
                                    )),
                                    DataCell(Text(p.narration)),
                                    DataCell(RowActions(
                                      onEdit:
                                          canEdit ? () => _openForm(p) : null,
                                      onDelete: canDelete
                                          ? () => _confirmDelete(p)
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
