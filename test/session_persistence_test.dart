import 'package:flutter_test/flutter_test.dart';

import 'package:pos/features/login/data/datasource/login_datasource.dart';
import 'package:pos/features/login/data/model/login_model.dart';
import 'package:pos/features/login/data/repository/login_repository.dart';
import 'package:pos/features/login/data/session_store.dart';
import 'package:pos/features/login/presentation/provider/login_provider.dart';

class _FakeSession implements SessionStore {
  LoginModel? stored;
  @override
  Future<void> save(LoginModel user) async => stored = user;
  @override
  Future<LoginModel?> read() async => stored;
  @override
  Future<void> clear() async => stored = null;
}

class _FakeDataSource extends LoginDataSource {
  const _FakeDataSource();

  @override
  Future<void> ensureSchema() async {}

  @override
  Future<LoginModel?> authenticate(String username, String password) async {
    if (username == 'admin' && password == 'admin123') {
      return const LoginModel(
        id: 1,
        username: 'admin',
        fullName: 'Administrator',
        role: 'admin',
        isActive: true,
      );
    }
    return null;
  }
}

void main() {
  LoginProvider make(_FakeSession s) =>
      LoginProvider(LoginRepository(const _FakeDataSource()), s);

  test('successful login is written to the session store', () async {
    final session = _FakeSession();
    final p = make(session);

    final ok = await p.login('admin', 'admin123');

    expect(ok, isTrue);
    expect(session.stored?.username, 'admin');
    expect(session.stored?.role, 'admin');
  });

  test('restore() signs the user back in from local storage', () async {
    final session = _FakeSession()
      ..stored = const LoginModel(
        id: 7,
        username: 'sara',
        fullName: 'Sara',
        role: 'cashier',
        isActive: true,
      );
    final p = make(session);

    expect(p.restoring, isTrue);
    await p.restore();

    expect(p.restoring, isFalse);
    expect(p.isLoggedIn, isTrue);
    expect(p.currentUser?.username, 'sara');
    expect(p.role, 'cashier');
  });

  test('logout clears the stored session', () async {
    final session = _FakeSession();
    final p = make(session);
    await p.login('admin', 'admin123');
    expect(session.stored, isNotNull);

    await p.logout();

    expect(session.stored, isNull);
    expect(p.isLoggedIn, isFalse);
  });

  test('failed login does not touch the session', () async {
    final session = _FakeSession();
    final p = make(session);

    final ok = await p.login('admin', 'wrong');

    expect(ok, isFalse);
    expect(session.stored, isNull);
  });
}
