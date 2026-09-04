import 'package:flutter/material.dart';
import 'package:pos/shared/app_icon.dart';

import '../../../../shared/feature_ui.dart';
import '../../data/permissions.dart';
import '../provider/permissions_provider.dart';

/// Permissions (admin): pick a user, give them their role's default access or a
/// custom set of View / Add / Edit / Delete rights per feature.
class PermissionsScreen extends StatefulWidget {
  const PermissionsScreen({super.key, this.provider});

  static const String routeName = '/permissions';

  final PermissionsProvider? provider;

  @override
  State<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends State<PermissionsScreen> {
  late final PermissionsProvider _provider =
      widget.provider ?? PermissionsProvider();

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

  Future<void> _save() async {
    final ok = await _provider.save();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? 'Access updated for ${_provider.selected?.displayName ?? 'user'}'
            : _provider.error ?? 'Could not save'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permissions'),
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
          if (_provider.error != null && _provider.users.isEmpty) {
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
                      subtitle: '${_provider.users.length}',
                    ),
                    StatCard(
                      title: 'Custom access',
                      subtitle: '${_provider.customCount}',
                      tint: const Color(0xFF1565C0),
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
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        width: 260,
                        child: _UserList(provider: _provider),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _provider.selected == null
                            ? const SectionCard(
                                title: 'Access',
                                child: EmptyState(
                                  icon: AppIcons.verified_user_outlined,
                                  title: 'Select a user to manage access',
                                ),
                              )
                            : _AccessEditor(
                                provider: _provider,
                                onSave: _save,
                              ),
                      ),
                    ],
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

// ---------------------------------------------------------------------------

class _UserList extends StatelessWidget {
  const _UserList({required this.provider});

  final PermissionsProvider provider;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SectionCard(
      title: 'Users',
      subtitle: 'Pick someone to edit',
      fillHeight: true,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      child: ListView.builder(
        itemCount: provider.users.length,
        itemBuilder: (context, i) {
          final u = provider.users[i];
          final selected = provider.selected?.id == u.id;
          return Material(
            color: selected ? scheme.primaryContainer : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => provider.select(u),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            u.displayName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            u.hasCustomPermissions ? 'Custom' : u.role,
                            style: TextStyle(
                                fontSize: 12, color: scheme.outline),
                          ),
                        ],
                      ),
                    ),
                    if (!u.isActive)
                      const AppIcon(AppIcons.block, size: 15, color: Colors.grey),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------

class _AccessEditor extends StatelessWidget {
  const _AccessEditor({required this.provider, required this.onSave});

  final PermissionsProvider provider;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final user = provider.selected!;
    final custom = provider.customMode;
    final editable = custom && !user.isAdmin;

    final groups = <String, List<FeaturePermission>>{};
    for (final f in kFeaturePermissions) {
      groups.putIfAbsent(f.group, () => []).add(f);
    }

    return SectionCard(
      title: 'Access — ${user.displayName}',
      subtitle: 'Role: ${user.role}',
      fillHeight: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (user.isAdmin)
            _InfoBanner(
              icon: AppIcons.shield_outlined,
              text: 'Admins always have full access. Change this person\'s '
                  'role on the Users screen to restrict them.',
            ),
          if (!user.isAdmin) ...[
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Role defaults'),
                  icon: AppIcon(AppIcons.badge_outlined),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Custom access'),
                  icon: AppIcon(AppIcons.tune),
                ),
              ],
              selected: {custom},
              onSelectionChanged: (s) => provider.setCustomMode(s.first),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  custom
                      ? 'Tick exactly what this user can do.'
                      : 'Using the built-in access for the "${user.role}" role.',
                  style: TextStyle(fontSize: 12, color: scheme.outline),
                ),
                const Spacer(),
                if (editable) ...[
                  TextButton(
                    onPressed: provider.grantAll,
                    child: const Text('Grant all'),
                  ),
                  TextButton(
                    onPressed: provider.clearAll,
                    child: const Text('Clear all'),
                  ),
                ],
              ],
            ),
          ],
          const Divider(height: 16),
          Expanded(
            child: ListView(
              children: [
                for (final entry in groups.entries) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                    child: Text(
                      entry.key.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: scheme.outline,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  for (final feature in entry.value)
                    _FeatureRow(
                      feature: feature,
                      provider: provider,
                      enabled: editable,
                    ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
          const Divider(height: 16),
          Row(
            children: [
              if (provider.dirty)
                Text(
                  'Unsaved changes',
                  style: TextStyle(
                      color: scheme.error, fontWeight: FontWeight.w600),
                ),
              const Spacer(),
              FilledButton.icon(
                onPressed:
                    (provider.dirty && !provider.saving) ? onSave : null,
                icon: provider.saving
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const AppIcon(AppIcons.save_outlined),
                label: const Text('Save changes'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.feature,
    required this.provider,
    required this.enabled,
  });

  final FeaturePermission feature;
  final PermissionsProvider provider;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final granted = feature.permissionKeys.where(provider.has).length;
    final total = feature.permissionKeys.length;
    final all = granted == total;
    final none = granted == 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Checkbox(
              tristate: true,
              value: all
                  ? true
                  : none
                      ? false
                      : null,
              onChanged: enabled
                  ? (v) => provider.toggleFeature(feature, v ?? false)
                  : null,
            ),
          ),
          SizedBox(
            width: 150,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(feature.label,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final action in feature.actions)
                    FilterChip(
                      label: Text(action.label),
                      selected: provider.has(permKey(feature.key, action)),
                      onSelected: enabled
                          ? (v) => provider.toggle(
                              permKey(feature.key, action), v)
                          : null,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.text});

  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          AppIcon(icon, size: 20, color: scheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: TextStyle(color: scheme.onSecondaryContainer)),
          ),
        ],
      ),
    );
  }
}
