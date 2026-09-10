import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos/shared/app_icon.dart';

import 'package:pos/features/customer/data/datasource/customer_datasource.dart';
import 'package:pos/features/customer/data/model/customer_model.dart';
import 'package:pos/features/customer/data/repository/customer_repository.dart';
import 'package:pos/features/customer/presentation/provider/customer_provider.dart';
import 'package:pos/features/customer/presentation/screen/customer_screen.dart';
import 'package:pos/features/customer/presentation/widget/customer_form_dialog.dart';

/// In-memory stand-in for the DB-backed data source.
class _FakeCustomerDataSource extends CustomerDataSource {
  _FakeCustomerDataSource();

  final List<CustomerModel> _rows = [];
  int _nextId = 1;

  @override
  Future<void> ensureSchema() async {}

  @override
  Future<List<CustomerModel>> fetchAll() async =>
      List.unmodifiable(_rows..sort((a, b) => a.name.compareTo(b.name)));

  @override
  Future<CustomerModel> insert(CustomerModel c) async {
    final saved = c.copyWith(id: _nextId++);
    _rows.add(saved);
    return saved;
  }

  @override
  Future<CustomerModel> update(CustomerModel c) async {
    final i = _rows.indexWhere((e) => e.id == c.id);
    _rows[i] = c;
    return c;
  }

  @override
  Future<void> delete(int id) async => _rows.removeWhere((e) => e.id == id);
}

void main() {
  CustomerProvider makeProvider() =>
      CustomerProvider(CustomerRepository(_FakeCustomerDataSource()));

  test('provider adds, updates and deletes', () async {
    final p = makeProvider();
    await p.load();
    expect(p.items, isEmpty);

    await p.save(const CustomerModel(
      name: 'Ahmed',
      email: 'a@b.com',
      phone: '0300',
      address: 'Lahore',
      openingBalance: 1000,
    ));
    expect(p.items, hasLength(1));
    expect(p.items.first.openingBalance, 1000);

    final id = p.items.first.id!;
    await p.save(p.items.first.copyWith(name: 'Ahmed Traders', isActive: false));
    expect(p.items.first.name, 'Ahmed Traders');
    expect(p.items.first.isActive, isFalse);

    await p.delete(id);
    expect(p.items, isEmpty);
  });

  testWidgets('screen shows a customer and opens the edit form', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final p = makeProvider();
    await p.save(const CustomerModel(name: 'Bilal', phone: '0321'));

    await tester.pumpWidget(
      MaterialApp(home: CustomerScreen(provider: p)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bilal'), findsOneWidget);
    expect(find.text('0321'), findsOneWidget);

    await tester.tap(find.byWidgetPredicate((w) => w is AppIcon && w.name == AppIcons.edit_outlined).first);
    await tester.pumpAndSettle();
    expect(find.byType(CustomerFormDialog), findsOneWidget);
    expect(find.text('Edit Customer'), findsOneWidget);
  });
}
