/// The permission catalog for the whole app.
///
/// A permission is a `"<feature>.<action>"` string, e.g. `"bank.edit"`.
/// Every feature screen has a `view` permission (controls whether it shows in
/// the sidebar); most also have `add` / `edit` / `delete`.
///
/// A user either uses the defaults for their [role] (see
/// [defaultPermissionsFor]) or carries a custom set assigned on the
/// Permissions screen. See `LoginModel.can`.
library;

/// One thing a user can be allowed to do on a feature.
enum PermAction {
  view,
  add,
  edit,
  delete;

  /// Human label for the Permissions screen.
  String get label => switch (this) {
        PermAction.view => 'View',
        PermAction.add => 'Add',
        PermAction.edit => 'Edit',
        PermAction.delete => 'Delete',
      };
}

/// Builds the canonical `"<feature>.<action>"` permission key.
String permKey(String feature, PermAction action) => '$feature.${action.name}';

/// A feature that appears on the Permissions screen, with the actions it
/// supports.
class FeaturePermission {
  const FeaturePermission({
    required this.key,
    required this.label,
    required this.group,
    this.actions = const [
      PermAction.view,
      PermAction.add,
      PermAction.edit,
      PermAction.delete,
    ],
  });

  /// Matches `NavDestination.permissionKey`.
  final String key;
  final String label;

  /// Sidebar group this feature belongs to.
  final String group;

  /// Actions that make sense for this feature. View-only screens list just
  /// [PermAction.view].
  final List<PermAction> actions;

  Iterable<String> get permissionKeys => actions.map((a) => permKey(key, a));
}

/// Every feature, in sidebar order. Keep the keys in sync with
/// `nav_destinations.dart`.
const List<FeaturePermission> kFeaturePermissions = [
  FeaturePermission(
    key: 'dashboard',
    label: 'Dashboard',
    group: 'Overview',
    actions: [PermAction.view],
  ),
  FeaturePermission(key: 'sale_invoice', label: 'Sale Invoice', group: 'Sales'),
  FeaturePermission(key: 'sale_return', label: 'Sale Return', group: 'Sales'),
  FeaturePermission(key: 'sale_exchange', label: 'Sale Exchange', group: 'Sales'),
  FeaturePermission(
      key: 'purchase', label: 'Purchase Invoice', group: 'Purchases'),
  FeaturePermission(
      key: 'purchase_return', label: 'Purchase Return', group: 'Purchases'),
  FeaturePermission(
      key: 'stock_inventory', label: 'Stock Inventory', group: 'Inventory'),
  FeaturePermission(
      key: 'product_catalog',
      label: 'Categories & Types',
      group: 'Inventory'),
  FeaturePermission(
      key: 'cash_register', label: 'Cash Register', group: 'Accounts'),
  FeaturePermission(key: 'bank', label: 'Bank', group: 'Accounts'),
  FeaturePermission(key: 'voucher', label: 'Voucher', group: 'Accounts'),
  FeaturePermission(key: 'expense', label: 'Expense', group: 'Accounts'),
  FeaturePermission(key: 'customer', label: 'Customers', group: 'Parties'),
  FeaturePermission(key: 'company', label: 'Companies', group: 'Parties'),
  FeaturePermission(
    key: 'party_ledger',
    label: 'Party Ledger',
    group: 'Parties',
    actions: [PermAction.view],
  ),
  FeaturePermission(
    key: 'reports',
    label: 'Reports',
    group: 'Reports',
    actions: [PermAction.view],
  ),
  FeaturePermission(
    key: 'receipt_settings',
    label: 'Receipt Settings',
    group: 'Administration',
    actions: [PermAction.view, PermAction.edit],
  ),
  FeaturePermission(
    key: 'backup',
    label: 'Backup',
    group: 'Administration',
    actions: [PermAction.view, PermAction.edit],
  ),
  FeaturePermission(key: 'users', label: 'Users', group: 'Administration'),
  FeaturePermission(
    key: 'permissions',
    label: 'Permissions',
    group: 'Administration',
    actions: [PermAction.view],
  ),
];

/// Feature by key, or `null` if unknown.
FeaturePermission? featurePermissionByKey(String key) {
  for (final f in kFeaturePermissions) {
    if (f.key == key) return f;
  }
  return null;
}

/// Every valid permission key in the catalog.
Set<String> allPermissionKeys() => {
      for (final f in kFeaturePermissions) ...f.permissionKeys,
    };

/// Feature keys the `cashier` role can touch by default.
const Set<String> _cashierFeatures = {
  'dashboard',
  'sale_invoice',
  'sale_return',
  'sale_exchange',
  'customer',
  'party_ledger',
  'cash_register',
  'stock_inventory',
};

Map<String, Set<String>> _buildRoleDefaults() {
  final all = allPermissionKeys();

  // Manager: everything except user administration.
  final manager = all
      .where((k) => !k.startsWith('users.') && !k.startsWith('permissions.'))
      .toSet();

  // Cashier: day-to-day selling. Can view/add/edit in their features but not
  // delete, and cannot remove stock.
  final cashier = <String>{
    for (final f in kFeaturePermissions)
      if (_cashierFeatures.contains(f.key))
        for (final a in f.actions)
          if (a != PermAction.delete) permKey(f.key, a),
  };

  return {
    'admin': all,
    'manager': manager,
    'cashier': cashier,
  };
}

/// Default permission set per role, used when a user has no custom set.
final Map<String, Set<String>> kRolePermissionDefaults = _buildRoleDefaults();

/// The permissions a [role] gets when no custom set is assigned.
Set<String> defaultPermissionsFor(String role) =>
    kRolePermissionDefaults[role] ?? const <String>{};
