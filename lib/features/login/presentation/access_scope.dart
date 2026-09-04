import 'package:flutter/widgets.dart';

import '../data/model/login_model.dart';
import '../data/permissions.dart';

/// Makes the signed-in user available to every feature screen so they can
/// show/hide Add / Edit / Delete based on the user's permissions.
///
/// Usage inside a screen:
/// ```dart
/// if (AccessScope.of(context).can('bank', PermAction.add)) ...
/// ```
class AccessScope extends InheritedWidget {
  const AccessScope({super.key, required this.user, required super.child});

  final LoginModel? user;

  static AccessScope of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AccessScope>();
    return scope ?? const AccessScope(user: null, child: SizedBox.shrink());
  }

  /// Whether the current user may perform [action] on [feature]. Defaults to
  /// allowed when there is no scope (e.g. a screen shown on its own in a test).
  bool can(String feature, [PermAction action = PermAction.view]) =>
      user?.can(feature, action) ?? true;

  bool canView(String feature) => can(feature, PermAction.view);

  @override
  bool updateShouldNotify(AccessScope oldWidget) =>
      !identical(oldWidget.user, user);
}
