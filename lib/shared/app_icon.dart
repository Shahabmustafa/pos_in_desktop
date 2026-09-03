// Icon names deliberately mirror Flutter's `Icons.*` (snake_case) so the
// migration away from the Material icon font stays one-to-one and greppable.
// ignore_for_file: constant_identifier_names

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Names of every SVG icon bundled under `assets/icons/`. Use these instead of
/// Flutter's `Icons.*` — the app renders its icons from SVG via [AppIcon], not
/// from the Material icon font.
class AppIcons {
  AppIcons._();

  static const String account_balance_outlined = 'account_balance_outlined';
  static const String account_balance_wallet_outlined = 'account_balance_wallet_outlined';
  static const String add = 'add';
  static const String assignment_return_outlined = 'assignment_return_outlined';
  static const String badge_outlined = 'badge_outlined';
  static const String bar_chart_outlined = 'bar_chart_outlined';
  static const String block = 'block';
  static const String business_outlined = 'business_outlined';
  static const String cancel = 'cancel';
  static const String category_outlined = 'category_outlined';
  static const String check = 'check';
  static const String check_circle = 'check_circle';
  static const String chevron_left = 'chevron_left';
  static const String chevron_right = 'chevron_right';
  static const String clear = 'clear';
  static const String clear_all = 'clear_all';
  static const String close = 'close';
  static const String copy = 'copy';
  static const String dashboard_outlined = 'dashboard_outlined';
  static const String delete_outline = 'delete_outline';
  static const String description_outlined = 'description_outlined';
  static const String dns_outlined = 'dns_outlined';
  static const String download = 'download';
  static const String edit_outlined = 'edit_outlined';
  static const String error_outline = 'error_outline';
  static const String event = 'event';
  static const String event_outlined = 'event_outlined';
  static const String grid_on = 'grid_on';
  static const String history = 'history';
  static const String inventory_2_outlined = 'inventory_2_outlined';
  static const String keyboard_return_outlined = 'keyboard_return_outlined';
  static const String lock_outline = 'lock_outline';
  static const String logout = 'logout';
  static const String manage_accounts_outlined = 'manage_accounts_outlined';
  static const String payments_outlined = 'payments_outlined';
  static const String pause_circle_outline = 'pause_circle_outline';
  static const String people_alt_outlined = 'people_alt_outlined';
  static const String person_outline = 'person_outline';
  static const String point_of_sale = 'point_of_sale';
  static const String point_of_sale_outlined = 'point_of_sale_outlined';
  static const String print_outlined = 'print_outlined';
  static const String receipt_long_outlined = 'receipt_long_outlined';
  static const String refresh = 'refresh';
  static const String save_outlined = 'save_outlined';
  static const String search = 'search';
  static const String shield_outlined = 'shield_outlined';
  static const String shopping_cart_outlined = 'shopping_cart_outlined';
  static const String swap_horiz_outlined = 'swap_horiz_outlined';
  static const String trending_up = 'trending_up';
  static const String tune = 'tune';
  static const String verified_user_outlined = 'verified_user_outlined';
  static const String visibility_off_outlined = 'visibility_off_outlined';
  static const String visibility_outlined = 'visibility_outlined';
}

/// Drop-in replacement for Flutter's [Icon] that renders a bundled SVG.
///
/// Pass a name from [AppIcons]. Like [Icon], when [size] or [color] are omitted
/// it falls back to the ambient [IconTheme].
class AppIcon extends StatelessWidget {
  const AppIcon(this.name, {super.key, this.size, this.color});

  final String name;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final double dimension = size ?? iconTheme.size ?? 24;
    final Color resolved =
        color ?? iconTheme.color ?? Theme.of(context).colorScheme.onSurface;
    return SvgPicture.asset(
      'assets/icons/$name.svg',
      width: dimension,
      height: dimension,
      colorFilter: ColorFilter.mode(resolved, BlendMode.srcIn),
    );
  }
}
