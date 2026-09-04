import 'dart:convert';

import '../permissions.dart';

/// An authenticated user of the POS app.
class LoginModel {
  const LoginModel({
    required this.id,
    required this.username,
    required this.fullName,
    required this.role,
    required this.isActive,
    this.customPermissions,
  });

  final int id;
  final String username;
  final String fullName;

  /// One of: `admin`, `manager`, `cashier`.
  final String role;
  final bool isActive;

  /// Custom access assigned on the Permissions screen. When `null` the user
  /// falls back to [defaultPermissionsFor] their [role]. An empty set means
  /// "custom access, nothing granted".
  final Set<String>? customPermissions;

  bool get isAdmin => role == 'admin';
  bool get isManager => role == 'manager';
  bool get isCashier => role == 'cashier';

  bool get hasCustomPermissions => customPermissions != null;

  String get displayName => fullName.isNotEmpty ? fullName : username;

  /// Permission keys actually in effect for this user.
  Set<String> get effectivePermissions =>
      customPermissions ?? defaultPermissionsFor(role);

  /// Whether this user may perform [action] on [feature]
  /// (e.g. `can('bank', PermAction.edit)`). Admins can always do everything.
  bool can(String feature, [PermAction action = PermAction.view]) =>
      isAdmin || effectivePermissions.contains(permKey(feature, action));

  /// Whether the [feature]'s screen should be visible to this user.
  bool canView(String feature) => can(feature, PermAction.view);

  LoginModel copyWith({
    String? username,
    String? fullName,
    String? role,
    bool? isActive,
    Set<String>? customPermissions,
    bool clearCustomPermissions = false,
  }) {
    return LoginModel(
      id: id,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      customPermissions: clearCustomPermissions
          ? null
          : (customPermissions ?? this.customPermissions),
    );
  }

  /// Parses the DB / session `permissions` value. Accepts a JSON array, a
  /// legacy comma-separated string, or an [Iterable]. Returns `null` for a
  /// missing value (→ role defaults) and an empty set for `"[]"`.
  static Set<String>? decodePermissions(Object? raw) {
    if (raw == null) return null;
    if (raw is Set<String>) return raw;
    if (raw is Iterable) return raw.map((e) => '$e').toSet();
    final text = raw.toString().trim();
    if (text.isEmpty) return null;
    try {
      final decoded = jsonDecode(text);
      if (decoded is List) return decoded.map((e) => '$e').toSet();
    } catch (_) {
      return text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet();
    }
    return null;
  }

  /// Serialises a custom permission set for storage. `null` stays `null`.
  static String? encodePermissions(Set<String>? perms) =>
      perms == null ? null : jsonEncode(perms.toList()..sort());

  factory LoginModel.fromMap(Map<String, dynamic> map) {
    return LoginModel(
      id: map['id'] as int,
      username: map['username'] as String,
      fullName: (map['full_name'] as String?) ?? '',
      role: (map['role'] as String?) ?? 'cashier',
      isActive: (map['is_active'] as bool?) ?? true,
      customPermissions: decodePermissions(map['permissions']),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'username': username,
        'full_name': fullName,
        'role': role,
        'is_active': isActive,
        'permissions': encodePermissions(customPermissions),
      };
}
