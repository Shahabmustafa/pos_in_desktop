import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos/shared/app_icon.dart';

import 'package:pos/features/login/data/datasource/login_datasource.dart';
import 'package:pos/features/login/data/model/login_model.dart';
import 'package:pos/features/login/data/repository/login_repository.dart';
import 'package:pos/features/login/presentation/provider/users_provider.dart';
import 'package:pos/features/login/presentation/screen/users_screen.dart';

class _FakeDataSource extends LoginDataSource {
  _FakeDataSource();

  final List<LoginModel> rows = [];
  final Map<int, String> passwords = {};
  int _id = 1;

  @override
  Future<void> ensureSchema() async {}

  @override
  Future<List<LoginModel>> fetchAll() async => List.of(rows);

  @override
  Future<LoginModel> insertUser({
    required String username,
    required String password,
    required String fullName,
    required String role,
    required bool isActive,
    Set<String>? customPermissions,
  }) async {
    final u = LoginModel(
      id: _id++,
      username: username,
      fullName: fullName,
      role: role,
      isActive: isActive,
    );
    rows.add(u);
    passwords[u.id] = LoginDataSource.hashPassword(password);
    return u;
  }

  @override
  Future<LoginModel> updateUser(LoginModel user, {String? newPassword}) async {
    rows[rows.indexWhere((e) => e.id == user.id)] = user;
    if (newPassword != null && newPassword.isNotEmpty) {
      passwords[user.id] = LoginDataSource.hashPassword(newPassword);
    }
    return user;
  }

  @override
  Future<void> deleteUser(int id) async {
    rows.removeWhere((e) => e.id == id);
    passwords.remove(id);
  }
}

void main() {
  (UsersProvider, _FakeDataSource) make() {
    final ds = _FakeDataSource();
    return (UsersProvider(LoginRepository(ds)), ds);
  }

  test('create, change role, keep vs change password, delete', () async {
    final (p, ds) = make();
    await p.load();

    await p.save(const UserDraft(
      username: 'sara',
      fullName: 'Sara Khan',
      role: 'cashier',
      isActive: true,
      password: 'pass1234',
    ));
    expect(p.items, hasLength(1));
    final id = p.items.first.id;
    final hashAfterCreate = ds.passwords[id];

    // Edit without a password keeps the old hash.
    await p.save(UserDraft(
      id: id,
      username: 'sara',
      fullName: 'Sara Khan',
      role: 'manager',
      isActive: true,
    ));
    expect(p.items.first.role, 'manager');
    expect(ds.passwords[id], hashAfterCreate);

    // Edit with a password changes the hash.
    await p.save(UserDraft(
      id: id,
      username: 'sara',
      fullName: 'Sara Khan',
      role: 'manager',
      isActive: false,
      password: 'newpass99',
    ));
    expect(p.items.first.isActive, isFalse);
    expect(ds.passwords[id], isNot(hashAfterCreate));

    await p.delete(id);
    expect(p.items, isEmpty);
  });

  test('counts by role and active', () async {
    final (p, _) = make();
    await p.load();
    await p.save(const UserDraft(
        username: 'a', fullName: '', role: 'admin', isActive: true, password: 'x123'));
    await p.save(const UserDraft(
        username: 'b', fullName: '', role: 'cashier', isActive: false, password: 'x123'));

    expect(p.roleCount('admin'), 1);
    expect(p.activeCount, 1);
  });

  testWidgets('screen lists a user and opens the edit form', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final (p, _) = make();
    await p.save(const UserDraft(
      username: 'admin',
      fullName: 'Administrator',
      role: 'admin',
      isActive: true,
      password: 'admin123',
    ));

    await tester.pumpWidget(MaterialApp(home: UsersScreen(provider: p)));
    await tester.pumpAndSettle();

    expect(find.text('admin'), findsOneWidget);
    expect(find.text('Administrator'), findsOneWidget);

    await tester.tap(find.byWidgetPredicate((w) => w is AppIcon && w.name == AppIcons.edit_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text('Edit User'), findsOneWidget);
  });
}
