import 'package:flutter/material.dart';
import 'package:pos/shared/app_icon.dart';

import '../../login/data/model/login_model.dart';
import '../../backup/presentation/screen/backup_screen.dart';
import '../../bank/presentation/screen/bank_screen.dart';
import '../../cash_register/presentation/screen/cash_register_screen.dart';
import '../../company/presentation/screen/company_screen.dart';
import '../../customer/presentation/screen/customer_screen.dart';
import '../../dashboard/presentation/screen/dashboard_screen.dart';
import '../../expense/presentation/screen/expense_screen.dart';
import '../../purchase/presentation/screen/purchase_screen.dart';
import '../../purchase_return/presentation/screen/purchase_return_screen.dart';
import '../../reports/presentation/screen/reports_screen.dart';
import '../../sale_exchange/presentation/screen/sale_exchange_screen.dart';
import '../../sale_invoice/presentation/screen/sale_invoice_screen.dart';
import '../../sale_return/presentation/screen/sale_return_screen.dart';
import '../../login/presentation/screen/permissions_screen.dart';
import '../../login/presentation/screen/users_screen.dart';
import '../../party_ledger/presentation/screen/party_ledger_screen.dart';
import '../../product_catalog/presentation/screen/product_catalog_screen.dart';
import '../../receipt_settings/presentation/screen/receipt_settings_screen.dart';
import '../../stock_inventory/presentation/screen/stock_inventory_screen.dart';
import '../../voucher/presentation/screen/voucher_screen.dart';

/// A single item in the sidebar.
class NavDestination {
  const NavDestination({
    required this.label,
    required this.icon,
    required this.builder,
    required this.permissionKey,
  });

  final String label;
  final String icon;
  final WidgetBuilder builder;

  /// Feature key used to check the `<key>.view` permission. Matches an entry in
  /// `kFeaturePermissions` (see `login/data/permissions.dart`).
  final String permissionKey;
}

/// A titled group of sidebar items.
class NavGroup {
  const NavGroup({required this.title, required this.items});

  final String title;
  final List<NavDestination> items;
}

/// Every feature of the app, grouped for the sidebar.
const List<NavGroup> kNavGroups = [
  NavGroup(
    title: 'Overview',
    items: [
      NavDestination(
        label: 'Dashboard',
        icon: AppIcons.dashboard_outlined,
        builder: _dashboard,
        permissionKey: 'dashboard',
      ),
    ],
  ),
  NavGroup(
    title: 'Sales',
    items: [
      NavDestination(
        label: 'Sale Invoice',
        icon: AppIcons.receipt_long_outlined,
        builder: _saleInvoice,
        permissionKey: 'sale_invoice',
      ),
      NavDestination(
        label: 'Sale Return',
        icon: AppIcons.assignment_return_outlined,
        builder: _saleReturn,
        permissionKey: 'sale_return',
      ),
      NavDestination(
        label: 'Sale Exchange',
        icon: AppIcons.swap_horiz_outlined,
        builder: _saleExchange,
        permissionKey: 'sale_exchange',
      ),
    ],
  ),
  NavGroup(
    title: 'Purchases',
    items: [
      NavDestination(
        label: 'Purchase Invoice',
        icon: AppIcons.shopping_cart_outlined,
        builder: _purchase,
        permissionKey: 'purchase',
      ),
      NavDestination(
        label: 'Purchase Return',
        icon: AppIcons.keyboard_return_outlined,
        builder: _purchaseReturn,
        permissionKey: 'purchase_return',
      ),
    ],
  ),
  NavGroup(
    title: 'Inventory',
    items: [
      NavDestination(
        label: 'Stock Inventory',
        icon: AppIcons.inventory_2_outlined,
        builder: _stockInventory,
        permissionKey: 'stock_inventory',
      ),
      NavDestination(
        label: 'Categories & Types',
        icon: AppIcons.category_outlined,
        builder: _productCatalog,
        permissionKey: 'product_catalog',
      ),
    ],
  ),
  NavGroup(
    title: 'Accounts',
    items: [
      NavDestination(
        label: 'Cash Register',
        icon: AppIcons.point_of_sale_outlined,
        builder: _cashRegister,
        permissionKey: 'cash_register',
      ),
      NavDestination(
        label: 'Bank',
        icon: AppIcons.account_balance_outlined,
        builder: _bank,
        permissionKey: 'bank',
      ),
      NavDestination(
        label: 'Voucher',
        icon: AppIcons.description_outlined,
        builder: _voucher,
        permissionKey: 'voucher',
      ),
      NavDestination(
        label: 'Expense',
        icon: AppIcons.payments_outlined,
        builder: _expense,
        permissionKey: 'expense',
      ),
    ],
  ),
  NavGroup(
    title: 'Parties',
    items: [
      NavDestination(
        label: 'Customers',
        icon: AppIcons.people_alt_outlined,
        builder: _customer,
        permissionKey: 'customer',
      ),
      NavDestination(
        label: 'Companies',
        icon: AppIcons.business_outlined,
        builder: _company,
        permissionKey: 'company',
      ),
      NavDestination(
        label: 'Party Ledger',
        icon: AppIcons.receipt_long_outlined,
        builder: _partyLedger,
        permissionKey: 'party_ledger',
      ),
    ],
  ),
  NavGroup(
    title: 'Reports',
    items: [
      NavDestination(
        label: 'Reports',
        icon: AppIcons.bar_chart_outlined,
        builder: _reports,
        permissionKey: 'reports',
      ),
    ],
  ),
  NavGroup(
    title: 'Administration',
    items: [
      NavDestination(
        label: 'Receipt Settings',
        icon: AppIcons.print_outlined,
        builder: _receiptSettings,
        permissionKey: 'receipt_settings',
      ),
      NavDestination(
        label: 'Backup',
        icon: AppIcons.history,
        builder: _backup,
        permissionKey: 'backup',
      ),
      NavDestination(
        label: 'Users',
        icon: AppIcons.manage_accounts_outlined,
        builder: _users,
        permissionKey: 'users',
      ),
      NavDestination(
        label: 'Permissions',
        icon: AppIcons.verified_user_outlined,
        builder: _permissions,
        permissionKey: 'permissions',
      ),
    ],
  ),
];

/// Flat list of every destination, in sidebar order.
final List<NavDestination> kNavDestinations = [
  for (final g in kNavGroups) ...g.items,
];

/// The groups a [user] is allowed to see: each group keeps only the
/// destinations the user has `view` permission on, and empty groups drop out.
/// A `null` user (should not happen past the auth gate) sees nothing.
List<NavGroup> visibleNavGroups(LoginModel? user) {
  if (user == null) return const [];
  final groups = <NavGroup>[];
  for (final group in kNavGroups) {
    final items =
        group.items.where((d) => user.canView(d.permissionKey)).toList();
    if (items.isNotEmpty) {
      groups.add(NavGroup(title: group.title, items: items));
    }
  }
  return groups;
}

// Top-level builders (const constructors keep the list `const`).
Widget _dashboard(BuildContext _) => const DashboardScreen();
Widget _saleInvoice(BuildContext _) => const SaleInvoiceScreen();
Widget _saleReturn(BuildContext _) => const SaleReturnScreen();
Widget _saleExchange(BuildContext _) => const SaleExchangeScreen();
Widget _purchase(BuildContext _) => const PurchaseScreen();
Widget _purchaseReturn(BuildContext _) => const PurchaseReturnScreen();
Widget _stockInventory(BuildContext _) => const StockInventoryScreen();
Widget _productCatalog(BuildContext _) => const ProductCatalogScreen();
Widget _bank(BuildContext _) => const BankScreen();
Widget _cashRegister(BuildContext _) => const CashRegisterScreen();
Widget _voucher(BuildContext _) => const VoucherScreen();
Widget _expense(BuildContext _) => const ExpenseScreen();
Widget _customer(BuildContext _) => const CustomerScreen();
Widget _company(BuildContext _) => const CompanyScreen();
Widget _partyLedger(BuildContext _) => const PartyLedgerScreen();
Widget _reports(BuildContext _) => const ReportsScreen();
Widget _receiptSettings(BuildContext _) => const ReceiptSettingsScreen();
Widget _backup(BuildContext _) => const BackupScreen();
Widget _users(BuildContext _) => const UsersScreen();
Widget _permissions(BuildContext _) => const PermissionsScreen();
