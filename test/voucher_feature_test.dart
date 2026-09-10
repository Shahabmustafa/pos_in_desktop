import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos/shared/app_icon.dart';

import 'package:pos/features/voucher/data/datasource/voucher_datasource.dart';
import 'package:pos/features/voucher/data/model/voucher_model.dart';
import 'package:pos/features/voucher/data/repository/voucher_repository.dart';
import 'package:pos/features/voucher/presentation/provider/voucher_provider.dart';
import 'package:pos/features/voucher/presentation/screen/voucher_screen.dart';

class _FakeDataSource extends VoucherDataSource {
  _FakeDataSource();

  final List<VoucherModel> rows = [];
  int _id = 1;

  @override
  Future<void> ensureSchema() async {}

  @override
  Future<List<VoucherModel>> fetchAll({VoucherType? type}) async =>
      rows.where((v) => type == null || v.type == type).toList();

  @override
  Future<VoucherModel> insert(VoucherModel v) async {
    final saved = v.copyWith(id: _id++);
    rows.add(saved);
    return saved;
  }

  @override
  Future<VoucherModel> update(VoucherModel v) async {
    rows[rows.indexWhere((e) => e.id == v.id)] = v;
    return v;
  }

  @override
  Future<void> delete(int id) async => rows.removeWhere((e) => e.id == id);
}

void main() {
  VoucherProvider makeProvider() =>
      VoucherProvider(VoucherRepository(_FakeDataSource()));

  VoucherModel v(VoucherType type, double amount) =>
      VoucherModel(date: DateTime(2026, 9, 1), type: type, party: 'X', amount: amount);

  test('totals and net cash', () async {
    final p = makeProvider();
    await p.load();

    await p.save(v(VoucherType.receipt, 40000));
    await p.save(v(VoucherType.payment, 15000));
    await p.save(v(VoucherType.payment, 5000));
    await p.save(v(VoucherType.journal, 12000));

    expect(p.totalReceipts, 40000);
    expect(p.totalPayments, 20000);
    expect(p.netCash, 20000);
  });

  test('filter by type', () async {
    final p = makeProvider();
    await p.load();
    await p.save(v(VoucherType.receipt, 10));
    await p.save(v(VoucherType.payment, 20));

    await p.filterByType(VoucherType.payment);
    expect(p.items, hasLength(1));
    expect(p.items.single.type, VoucherType.payment);
  });

  test('nextNumber increments per type with prefix', () async {
    final p = makeProvider();
    await p.load();
    expect(p.nextNumber(VoucherType.payment), 'PV-0001');
    await p.save(v(VoucherType.payment, 100));
    expect(p.nextNumber(VoucherType.payment), 'PV-0002');
    expect(p.nextNumber(VoucherType.receipt), 'RV-0001');
  });

  testWidgets('screen lists a voucher and opens the edit form', (tester) async {
    tester.view.physicalSize = const Size(1300, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final p = makeProvider();
    await p.save(v(VoucherType.receipt, 40000).copyWith(voucherNo: 'RV-0001'));

    await tester.pumpWidget(MaterialApp(home: VoucherScreen(provider: p)));
    await tester.pumpAndSettle();

    expect(find.text('RV-0001'), findsOneWidget);
    expect(find.text('Add Voucher'), findsWidgets);

    await tester.tap(find.byWidgetPredicate((w) => w is AppIcon && w.name == AppIcons.edit_outlined).first);
    await tester.pumpAndSettle();
    expect(find.text('Edit Voucher'), findsOneWidget);
  });
}
