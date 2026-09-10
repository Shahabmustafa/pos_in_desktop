import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos/shared/app_icon.dart';

import 'package:pos/features/login/data/model/login_model.dart';
import 'package:pos/features/login/presentation/provider/login_provider.dart';
import 'package:pos/features/shell/presentation/home_shell.dart';
import 'package:pos/features/shell/presentation/nav_destinations.dart';

class _LoggedInProvider extends LoginProvider {
  @override
  LoginModel? get currentUser => const LoginModel(
        id: 1,
        username: 'admin',
        fullName: 'Administrator',
        role: 'admin',
        isActive: true,
      );
}

void main() {
  testWidgets('sidebar lists every feature and switches screens',
      (tester) async {
    // Tall enough that the whole sidebar nav list fits without scrolling.
    tester.view.physicalSize = const Size(1400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(home: HomeShell(auth: _LoggedInProvider())),
    );

    // Every destination label is present in the sidebar.
    for (final d in kNavDestinations) {
      expect(find.text(d.label), findsWidgets, reason: d.label);
    }

    // Default screen is the first destination (Dashboard).
    expect(find.widgetWithText(AppBar, 'Dashboard'), findsOneWidget);

    // Tapping "Bank" shows the Bank screen.
    await tester.tap(find.text('Bank').first);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Bank'), findsOneWidget);
  });

  testWidgets('collapsing and expanding the sidebar does not overflow',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(home: HomeShell(auth: _LoggedInProvider())),
    );
    await tester.pumpAndSettle();

    // Collapse — pump through the 180ms animation frame by frame.
    await tester.tap(find.byWidgetPredicate((w) => w is AppIcon && w.name == AppIcons.chevron_left));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byWidgetPredicate((w) => w is AppIcon && w.name == AppIcons.chevron_right), findsOneWidget);

    // Expand again.
    await tester.tap(find.byWidgetPredicate((w) => w is AppIcon && w.name == AppIcons.chevron_right));
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('user name and role show in the footer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: HomeShell(auth: _LoggedInProvider())),
    );

    expect(find.text('Administrator'), findsOneWidget);
    expect(find.text('admin'), findsOneWidget);
  });
}
