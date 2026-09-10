import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos/features/login/data/datasource/login_datasource.dart';
import 'package:pos/features/login/data/model/login_model.dart';
import 'package:pos/features/login/data/permissions.dart';
import 'package:pos/features/login/data/repository/login_repository.dart';
import 'package:pos/features/login/presentation/provider/permissions_provider.dart';
import 'package:pos/features/login/presentation/screen/permissions_screen.dart';
import 'package:pos/features/shell/presentation/nav_destinations.dart';

class _FakeDataSource extends LoginDataSource {
  _FakeDataSource(this.rows);

  final List<LoginModel> rows;

  @override
  Future<void> ensureSchema() async {}

  @override
  Future<List<LoginModel>> fetchAll() async => List.of(rows);

  @override
  Future<LoginModel> setPermissions(int id, Set<String>? permissions) async {
    final i = rows.indexWhere((u) => u.id == id);
    final updated = rows[i].copyWith(
      customPermissions: permissions,
      clearCustomPermissions: permissions == null,
    );
    rows[i] = updated;
    return updated;
  }
}

LoginModel _user(int id, String name, String role, {Set<String>? perms}) =>
    LoginModel(
      id: id,
      username: name,
      fullName: name,
      role: role,
      isActive: true,
      customPermissions: perms,
    );

void main() {
  group('LoginModel.can', () {
    test('admin can do everything, even without a custom set', () {
      final admin = _user(1, 'admin', 'admin');
      expect(admin.can('users', PermAction.delete), isTrue);
      expect(admin.can('bank', PermAction.add), isTrue);
    });

    test('cashier uses role defaults: sells but cannot see Users', () {
      final cashier = _user(2, 'sara', 'cashier');
      expect(cashier.canView('sale_invoice'), isTrue);
      expect(cashier.can('sale_invoice', PermAction.add), isTrue);
      expect(cashier.can('sale_invoice', PermAction.delete), isFalse);
      expect(cashier.canView('users'), isFalse);
      expect(cashier.canView('bank'), isFalse);
    });

    test('a custom set overrides role defaults entirely', () {
      final u = _user(3, 'omar', 'cashier', perms: {'bank.view', 'bank.edit'});
      expect(u.canView('bank'), isTrue);
      expect(u.can('bank', PermAction.edit), isTrue);
      expect(u.can('bank', PermAction.delete), isFalse);
      // Lost the cashier defaults because a custom set is present.
      expect(u.canView('sale_invoice'), isFalse);
    });

    test('empty custom set means no access (non-admin)', () {
      final u = _user(4, 'locked', 'manager', perms: <String>{});
      expect(u.hasCustomPermissions, isTrue);
      expect(u.canView('dashboard'), isFalse);
    });
  });

  group('permission encode/decode', () {
    test('round-trips through a JSON string', () {
      final encoded = LoginModel.encodePermissions({'b.view', 'a.add'});
      expect(encoded, '["a.add","b.view"]');
      expect(LoginModel.decodePermissions(encoded), {'a.add', 'b.view'});
    });

    test('null stays null, "[]" is an empty set', () {
      expect(LoginModel.encodePermissions(null), isNull);
      expect(LoginModel.decodePermissions(null), isNull);
      expect(LoginModel.decodePermissions('[]'), isEmpty);
    });

    test('toMap/fromMap preserve a custom set', () {
      final u = _user(5, 'x', 'cashier', perms: {'reports.view'});
      final back = LoginModel.fromMap(u.toMap());
      expect(back.customPermissions, {'reports.view'});
    });
  });

  group('visibleNavGroups', () {
    test('admin sees every destination', () {
      final groups = visibleNavGroups(_user(1, 'a', 'admin'));
      final labels = [for (final g in groups) for (final d in g.items) d.label];
      expect(labels, containsAll(['Dashboard', 'Users', 'Permissions', 'Bank']));
    });

    test('cashier sees only their features and no empty groups', () {
      final groups = visibleNavGroups(_user(2, 'c', 'cashier'));
      final labels = [for (final g in groups) for (final d in g.items) d.label];
      expect(labels, contains('Sale Invoice'));
      expect(labels, isNot(contains('Users')));
      expect(labels, isNot(contains('Bank')));
      expect(groups.map((g) => g.title), isNot(contains('Administration')));
    });

    test('null user sees nothing', () {
      expect(visibleNavGroups(null), isEmpty);
    });
  });

  group('PermissionsProvider', () {
    PermissionsProvider make(List<LoginModel> rows) =>
        PermissionsProvider(LoginRepository(_FakeDataSource(rows)));

    test('assigns a custom set and clears back to role defaults', () async {
      final rows = [_user(2, 'sara', 'cashier')];
      final p = make(rows);
      await p.load();

      expect(p.selected?.username, 'sara');
      expect(p.customMode, isFalse);

      p.toggle('bank.view', true);
      expect(p.customMode, isTrue);
      expect(p.dirty, isTrue);

      expect(await p.save(), isTrue);
      expect(p.selected?.customPermissions, contains('bank.view'));
      expect(p.dirty, isFalse);

      // Switch back to role defaults and save → custom set cleared.
      p.setCustomMode(false);
      expect(await p.save(), isTrue);
      expect(p.selected?.hasCustomPermissions, isFalse);
    });

    test('toggleFeature ticks every action at once', () async {
      final p = make([_user(2, 'sara', 'cashier')]);
      await p.load();
      final bank = featurePermissionByKey('bank')!;
      p.toggleFeature(bank, true);
      for (final key in bank.permissionKeys) {
        expect(p.has(key), isTrue);
      }
    });
  });

  testWidgets('screen lists users and shows the access editor', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final provider = PermissionsProvider(
      LoginRepository(_FakeDataSource([
        _user(1, 'admin', 'admin'),
        _user(2, 'sara', 'cashier'),
      ])),
    );
    await provider.load();

    await tester.pumpWidget(
      MaterialApp(home: PermissionsScreen(provider: provider)),
    );
    await tester.pumpAndSettle();

    expect(find.text('sara'), findsWidgets);
    expect(find.textContaining('Access'), findsWidgets);

    // Pick the cashier → the "Role defaults / Custom access" toggle appears.
    await tester.tap(find.text('sara').first);
    await tester.pumpAndSettle();
    expect(find.text('Role defaults'), findsOneWidget);
    expect(find.text('Custom access'), findsOneWidget);
  });
}
