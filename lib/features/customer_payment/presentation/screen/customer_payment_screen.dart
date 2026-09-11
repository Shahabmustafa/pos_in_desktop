import 'package:flutter/material.dart';
import 'package:pos/shared/app_icon.dart';

import '../../../../config/format.dart';
import '../../../../shared/feature_ui.dart';
import '../../../login/data/permissions.dart';
import '../../../login/presentation/access_scope.dart';
import '../../data/model/customer_payment_model.dart';
import '../provider/customer_payment_provider.dart';
import '../widget/customer_payment_form_dialog.dart';

/// Customer Payment module: money collected from a customer against their
/// outstanding balance, independent of any particular sale invoice.
class CustomerPaymentScreen extends StatefulWidget {
  const CustomerPaymentScreen({super.key, this.provider});

  static const String routeName = '/customer_payment';

  final CustomerPaymentProvider? provider;

  @override
  State<CustomerPaymentScreen> createState() => _CustomerPaymentScreenState();
}

class _CustomerPaymentScreenState extends State<CustomerPaymentScreen> {
  late final CustomerPaymentProvider _provider =
      widget.provider ?? CustomerPaymentProvider();

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

  Future<void> _openForm([CustomerPaymentModel? existing]) async {
    final result = await showDialog<CustomerPaymentModel>(
      context: context,
      builder: (_) => CustomerPaymentFormDialog(
        initial: existing,
        customers: _provider.customers,
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

  Future<void> _confirmDelete(CustomerPaymentModel p) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete payment?'),
        content: Text(
            'Payment "${p.paymentNo.isEmpty ? p.customerName : p.paymentNo}" '
            'will be removed and added back to the customer\'s due amount.'),
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
    final canAdd = access.can('customer_payment', PermAction.add);
    final canEdit = access.can('customer_payment', PermAction.edit);
    final canDelete = access.can('customer_payment', PermAction.delete);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receive Payment'),
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

          final dueCustomers =
              _provider.customers.where((c) => c.openingBalance > 0).length;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
                child: StatCardRow(
                  cards: [
                    StatCard(
                      title: 'Total collected',
                      subtitle: Fmt.money(_provider.totalCollected),
                      tint: const Color(0xFF2E7D32),
                    ),
                    StatCard(
                      title: 'Customers with dues',
                      subtitle: '$dueCustomers',
                      tint: const Color(0xFFC62828),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                  child: SectionCard(
                    title: 'Payments',
                    subtitle: 'Amounts collected from customers against their due balance',
                    fillHeight: true,
                    trailing: canAdd
                        ? FilledButton.icon(
                            onPressed: () => _openForm(),
                            icon: const AppIcon(AppIcons.add),
                            label: const Text('Receive Payment'),
                          )
                        : null,
                    child: _provider.items.isEmpty
                        ? EmptyState(
                            icon: AppIcons.account_balance_wallet_outlined,
                            title: 'No payments recorded yet',
                            actionLabel: canAdd ? 'Receive Payment' : null,
                            onAction: canAdd ? () => _openForm() : null,
                          )
                        : ScrollableTable(
                            flexColumn: 6, // Narration
                            columns: const [
                              DataColumn(label: Text('Payment #')),
                              DataColumn(label: Text('Date')),
                              DataColumn(label: Text('Customer')),
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
                                    DataCell(Text(p.customerName)),
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
