import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos/features/login/data/datasource/login_datasource.dart';
import 'package:pos/features/login/data/model/login_model.dart';
import 'package:pos/features/login/data/repository/login_repository.dart';
import 'package:pos/features/login/data/session_store.dart';
import 'package:pos/features/login/presentation/provider/login_provider.dart';
import 'package:pos/features/login/presentation/screen/login_screen.dart';

/// In-memory session, so tests don't touch the shared_preferences plugin.
class _FakeSession implements SessionStore {
  LoginModel? _stored;
  @override
  Future<void> save(LoginModel user) async => _stored = user;
  @override
  Future<LoginModel?> read() async => _stored;
  @override
  Future<void> clear() async => _stored = null;
}

/// In-memory stand-in for the DB-backed data source.
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
  LoginProvider makeProvider() =>
      LoginProvider(LoginRepository(const _FakeDataSource()), _FakeSession());

  testWidgets('shows username and password fields', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(provider: makeProvider())),
    );

    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign In'), findsOneWidget);
  });

  testWidgets('rejects wrong credentials', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(provider: makeProvider())),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'admin');
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid username or password'), findsOneWidget);
  });

  testWidgets('accepts correct credentials and exposes role', (tester) async {
    final provider = makeProvider();
    await tester.pumpWidget(
      MaterialApp(home: LoginScreen(provider: provider)),
    );

    await tester.enterText(find.byType(TextFormField).at(0), 'admin');
    await tester.enterText(find.byType(TextFormField).at(1), 'admin123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign In'));
    await tester.pumpAndSettle();

    expect(provider.isLoggedIn, isTrue);
    expect(provider.role, 'admin');
    expect(provider.currentUser!.username, 'admin');
  });
}
