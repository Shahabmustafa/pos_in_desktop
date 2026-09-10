import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos/features/stock_inventory/data/datasource/stock_inventory_datasource.dart';
import 'package:pos/features/stock_inventory/data/model/named_ref.dart';
import 'package:pos/features/stock_inventory/data/model/stock_item_model.dart';
import 'package:pos/features/stock_inventory/data/repository/stock_inventory_repository.dart';
import 'package:pos/features/stock_inventory/presentation/provider/stock_inventory_provider.dart';
import 'package:pos/features/stock_inventory/presentation/screen/stock_inventory_screen.dart';

class _FakeDataSource extends StockInventoryDataSource {
  _FakeDataSource();

  final List<StockItemModel> rows = [];
  int _id = 1;

  @override
  Future<void> ensureSchema() async {}

  @override
  Future<List<NamedRef>> fetchCompanies() async => const [
        NamedRef(id: 1, name: 'Coca-Cola'),
        NamedRef(id: 2, name: 'Nestlé'),
      ];

  @override
  Future<List<NamedRef>> fetchCategories() async => const [
        NamedRef(id: 10, name: 'Beverages'),
        NamedRef(id: 11, name: 'Snacks'),
      ];

  @override
  Future<List<NamedRef>> fetchInventoryTypes() async => const [
        NamedRef(id: 20, name: 'Finished Goods'),
        NamedRef(id: 21, name: 'Raw Material'),
      ];

  @override
  Future<List<StockItemModel>> fetchAll() async => List.of(rows);

  @override
  Future<StockItemModel> insert(StockItemModel i) async {
    final saved = i.copyWith(id: _id++);
    rows.add(saved);
    return saved;
  }

  @override
  Future<StockItemModel> update(StockItemModel i) async {
    rows[rows.indexWhere((e) => e.id == i.id)] = i;
    return i;
  }

  @override
  Future<void> delete(int id) async => rows.removeWhere((e) => e.id == id);
}

void main() {
  StockInventoryProvider makeProvider() =>
      StockInventoryProvider(StockInventoryRepository(_FakeDataSource()));

  test('add / update / delete and category + active counts', () async {
    final p = makeProvider();
    await p.load();
    expect(p.items, isEmpty);

    await p.save(const StockItemModel(
      name: 'Cola',
      barcode: '5449000000996',
      companyName: 'Coca-Cola',
      inventoryType: 'Finished Goods',
      category: 'Beverages',
      purchasePrice: 95,
      salePrice: 120,
      discount: 0,
      tax: 16,
    ));
    await p.save(const StockItemModel(
      name: 'Chips',
      category: 'Snacks',
      isActive: false,
    ));
    await p.save(const StockItemModel(name: 'Water', category: 'Beverages'));

    expect(p.items, hasLength(3));
    expect(p.activeCount, 2);
    expect(p.categoryCount, 2); // Beverages, Snacks

    final cola = p.items.firstWhere((i) => i.name == 'Cola');
    await p.save(cola.copyWith(category: 'Soft Drinks', tax: 17));
    expect(p.items.firstWhere((i) => i.name == 'Cola').category, 'Soft Drinks');
    expect(p.categoryCount, 3);

    await p.delete(cola.id!);
    expect(p.items, hasLength(2));
  });

  test('stores company / category / type ids and resolves their names',
      () async {
    final p = makeProvider();
    await p.load();
    await p.save(const StockItemModel(
      name: 'Cola',
      companyId: 1,
      categoryId: 10,
      inventoryTypeId: 20,
    ));

    final item = p.items.single;
    expect(item.companyId, 1);
    expect(item.categoryId, 10);
    expect(item.inventoryTypeId, 20);
    // Names come from the master lists, not from the row.
    expect(item.companyName, 'Coca-Cola');
    expect(item.category, 'Beverages');
    expect(item.inventoryType, 'Finished Goods');
  });

  test('expiry date round-trips and can be cleared', () async {
    final p = makeProvider();
    await p.load();
    await p.save(StockItemModel(name: 'Milk', expiryDate: DateTime(2026, 12, 1)));
    expect(p.items.first.expiryDate, DateTime(2026, 12, 1));

    await p.save(p.items.first.copyWith(expiryDate: null));
    expect(p.items.first.expiryDate, isNull);
  });

  testWidgets('screen shows the product and its columns', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final p = makeProvider();
    await p.save(const StockItemModel(
      name: 'Cola',
      barcode: 'BAR123',
      companyName: 'Coca-Cola',
      inventoryType: 'Finished Goods',
      category: 'Beverages',
    ));

    await tester.pumpWidget(
      MaterialApp(home: StockInventoryScreen(provider: p)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Stock Inventory'), findsOneWidget);
    expect(find.text('Cola'), findsOneWidget);
    expect(find.text('BAR123'), findsOneWidget);
    expect(find.text('Coca-Cola'), findsOneWidget);
    expect(find.text('Beverages'), findsOneWidget);
    // No "Stock Movements" tab any more.
    expect(find.text('Stock Movements'), findsNothing);
    expect(find.byType(Tab), findsNothing);
  });
}
