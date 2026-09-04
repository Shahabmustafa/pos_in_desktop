import 'package:flutter/material.dart';
import 'package:pos/shared/app_icon.dart';

import '../../../../shared/feature_ui.dart';
import '../../data/model/login_model.dart';
import '../../data/permissions.dart';
import '../access_scope.dart';
import '../provider/users_provider.dart';
import '../widget/user_form_dialog.dart';

/// User management (admin): list + add / edit / delete app users.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key, this.provider});

  static const String routeName = '/users';

  final UsersProvider? provider;

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  late final UsersProvider _provider = widget.provider ?? UsersProvider();

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

  Future<void> _openForm([LoginModel? existing]) async {
    final draft = await showDialog<UserDraft>(
      context: context,
      builder: (_) => UserFormDialog(initial: existing),
    );
    if (draft == null) return;
    final ok = await _provider.save(draft);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User "${draft.username}" saved')),
      );
    }
  }

  Future<void> _confirmDelete(LoginModel u) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete user?'),
        content: Text('"${u.username}" will no longer be able to log in.'),
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
    if (yes == true) await _provider.delete(u.id);
  }

  @override
  Widget build(BuildContext context) {
    final access = AccessScope.of(context);
    final canAdd = access.can('users', PermAction.add);
    final canEdit = access.can('users', PermAction.edit);
    final canDelete = access.can('users', PermAction.delete);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Users'),
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
                      title: 'Users',
                      subtitle: '${_provider.items.length}',
                    ),
                    StatCard(
                      title: 'Active',
                      subtitle: '${_provider.activeCount}',
                      tint: const Color(0xFF2E7D32),
                    ),
                    StatCard(
                      title: 'Admins',
                      subtitle: '${_provider.roleCount('admin')}',
                      tint: const Color(0xFF6A1B9A),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                  child: SectionCard(
                    title: 'Users',
                    subtitle: 'People who can sign in to the POS',
                    fillHeight: true,
                    trailing: canAdd
                        ? FilledButton.icon(
                            onPressed: () => _openForm(),
                            icon: const AppIcon(AppIcons.add),
                            label: const Text('Add User'),
                          )
                        : null,
                    child: _provider.items.isEmpty
                        ? EmptyState(
                            icon: AppIcons.person_outline,
                            title: 'No users yet',
                            actionLabel: canAdd ? 'Add User' : null,
                            onAction: canAdd ? () => _openForm() : null,
                          )
                        : ScrollableTable(
                            flexColumn: 1, // Full name
                            columns: const [
                              DataColumn(label: Text('Username')),
                              DataColumn(label: Text('Full name')),
                              DataColumn(label: Text('Role')),
                              DataColumn(label: Text('Active')),
                              DataColumn(label: Text('')),
                            ],
                            rows: [
                              for (final u in _provider.items)
                                DataRow(
                                  onSelectChanged:
                                      canEdit ? (_) => _openForm(u) : null,
                                  cells: [
                                    DataCell(Text(u.username,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600))),
                                    DataCell(Text(u.fullName)),
                                    DataCell(StatusPill(
                                      text: u.role[0].toUpperCase() +
                                          u.role.substring(1),
                                      color: switch (u.role) {
                                        'admin' => Colors.deepPurple,
                                        'manager' => Colors.indigo,
                                        _ => Colors.teal,
                                      },
                                    )),
                                    DataCell(ActiveDot(active: u.isActive)),
                                    DataCell(RowActions(
                                      onEdit:
                                          canEdit ? () => _openForm(u) : null,
                                      onDelete: canDelete
                                          ? () => _confirmDelete(u)
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
