import 'package:flutter/material.dart';
import 'package:pos/shared/app_icon.dart';

import '../../login/data/model/login_model.dart';
import '../../login/presentation/access_scope.dart';
import '../../login/presentation/provider/login_provider.dart';
import 'nav_destinations.dart';

/// The main app frame after login: a persistent sidebar with every feature
/// on the left and the selected screen on the right.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.auth});

  final LoginProvider auth;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selected = 0;
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final user = widget.auth.currentUser;
    final groups = visibleNavGroups(user);
    final destinations = [for (final g in groups) ...g.items];

    if (destinations.isEmpty) {
      return Scaffold(
        body: _NoAccess(onLogout: widget.auth.logout),
      );
    }

    final selected = _selected.clamp(0, destinations.length - 1);

    return AccessScope(
      user: user,
      child: Scaffold(
        body: Row(
          children: [
            _Sidebar(
              collapsed: _collapsed,
              groups: groups,
              selectedIndex: selected,
              user: user,
              onSelect: (i) => setState(() => _selected = i),
              onToggleCollapse: () => setState(() => _collapsed = !_collapsed),
              onLogout: widget.auth.logout,
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: ClipRect(
                child: destinations[selected].builder(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when a user has no permission to view any screen at all.
class _NoAccess extends StatelessWidget {
  const _NoAccess({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppIcon(AppIcons.lock_outline, size: 40),
          const SizedBox(height: 12),
          const Text('You do not have access to any screen.'),
          const SizedBox(height: 4),
          const Text('Ask an administrator to grant you permissions.'),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onLogout,
            icon: const AppIcon(AppIcons.logout),
            label: const Text('Logout'),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.collapsed,
    required this.groups,
    required this.selectedIndex,
    required this.user,
    required this.onSelect,
    required this.onToggleCollapse,
    required this.onLogout,
  });

  final bool collapsed;
  final List<NavGroup> groups;
  final int selectedIndex;
  final LoginModel? user;
  final ValueChanged<int> onSelect;
  final VoidCallback onToggleCollapse;
  final VoidCallback onLogout;

  static const double _expandedWidth = 256;
  static const double _collapsedWidth = 72;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final targetWidth = collapsed ? _collapsedWidth : _expandedWidth;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: targetWidth,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(color: scheme.surface),
      // Force the content to the final width even while the container is
      // mid-animation, so nothing overflows during the transition.
      child: OverflowBox(
        alignment: Alignment.centerLeft,
        minWidth: targetWidth,
        maxWidth: targetWidth,
        child: SizedBox(
          width: targetWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(collapsed: collapsed, onToggleCollapse: onToggleCollapse),
              const Divider(height: 1),
              Expanded(
                child: _NavList(
                  collapsed: collapsed,
                  groups: groups,
                  selectedIndex: selectedIndex,
                  onSelect: onSelect,
                ),
              ),
              const Divider(height: 1),
              _UserFooter(
                collapsed: collapsed,
                user: user,
                onLogout: onLogout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.collapsed, required this.onToggleCollapse});

  final bool collapsed;
  final VoidCallback onToggleCollapse;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Collapsed: just the expand toggle, centered.
    if (collapsed) {
      return SizedBox(
        height: 64,
        child: Center(
          child: IconButton(
            tooltip: 'Expand',
            icon: const AppIcon(AppIcons.chevron_right),
            onPressed: onToggleCollapse,
          ),
        ),
      );
    }

    return Container(
      height: 64,
      padding: const EdgeInsets.only(left: 14, right: 4),
      child: Row(
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const AppIcon(AppIcons.point_of_sale, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'POS',
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Collapse',
            visualDensity: VisualDensity.compact,
            icon: const AppIcon(AppIcons.chevron_left),
            onPressed: onToggleCollapse,
          ),
        ],
      ),
    );
  }
}

class _NavList extends StatelessWidget {
  const _NavList({
    required this.collapsed,
    required this.groups,
    required this.selectedIndex,
    required this.onSelect,
  });

  final bool collapsed;
  final List<NavGroup> groups;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    var flatIndex = 0;
    final children = <Widget>[];

    for (final group in groups) {
      if (!collapsed) {
        children.add(Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 6),
          child: Text(
            group.title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.outline,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ));
      } else {
        children.add(const SizedBox(height: 8));
      }

      for (final item in group.items) {
        final index = flatIndex;
        final selected = index == selectedIndex;
        children.add(_NavTile(
          icon: item.icon,
          label: item.label,
          collapsed: collapsed,
          selected: selected,
          onTap: () => onSelect(index),
        ));
        flatIndex++;
      }
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 12),
      children: children,
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.collapsed,
    required this.selected,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool collapsed;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;

    final tile = Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: EdgeInsets.symmetric(
        horizontal: collapsed ? 0 : 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: selected ? scheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment:
            collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          AppIcon(icon, size: 20, color: fg),
          if (!collapsed) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: fg,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: collapsed
            ? Tooltip(message: label, child: tile)
            : tile,
      ),
    );
  }
}

class _UserFooter extends StatelessWidget {
  const _UserFooter({
    required this.collapsed,
    required this.user,
    required this.onLogout,
  });

  final bool collapsed;
  final LoginModel? user;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = user?.displayName ?? 'User';
    final role = user?.role ?? '';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';

    if (collapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: scheme.primaryContainer,
              child: Text(initial,
                  style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w700)),
            ),
            IconButton(
              tooltip: 'Logout',
              icon: const AppIcon(AppIcons.logout, size: 20),
              onPressed: onLogout,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: scheme.primaryContainer,
            child: Text(initial,
                style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                if (role.isNotEmpty)
                  Text(role,
                      style: TextStyle(
                          fontSize: 12, color: scheme.outline)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Logout',
            icon: const AppIcon(AppIcons.logout, size: 20),
            onPressed: onLogout,
          ),
        ],
      ),
    );
  }
}
