import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos/shared/searchable_dropdown.dart';

Widget _host(Widget child) => MaterialApp(
      home: Scaffold(
        body: Padding(padding: const EdgeInsets.all(24), child: child),
      ),
    );

void main() {
  testWidgets('picks a value from the filtered list', (tester) async {
    String? selected;
    await tester.pumpWidget(_host(
      SearchableDropdown<String>(
        items: const ['Apple', 'Banana', 'Cherry'],
        value: null,
        hintText: 'Fruit',
        onChanged: (v) => selected = v,
      ),
    ));

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ban');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Banana').last);
    await tester.pumpAndSettle();

    expect(selected, 'Banana');
  });

  testWidgets('allowCustom keeps a typed value that is not in the list',
      (tester) async {
    String? selected;
    await tester.pumpWidget(_host(
      SearchableDropdown<String>(
        items: const ['Beverages', 'Snacks'],
        value: null,
        hintText: 'Category',
        allowCustom: true,
        onChanged: (v) => selected = v,
      ),
    ));

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Frozen Foods');
    await tester.pumpAndSettle();

    expect(selected, 'Frozen Foods');
  });

  testWidgets('includeNull adds an "all" entry', (tester) async {
    int? selected = 1;
    await tester.pumpWidget(_host(
      StatefulBuilder(
        builder: (context, setState) => SearchableDropdown<int>(
          items: const [1, 2, 3],
          value: selected,
          includeNull: true,
          nullLabel: 'All',
          itemLabel: (i) => 'Item $i',
          onChanged: (v) => setState(() => selected = v),
        ),
      ),
    ));

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All').last);
    await tester.pumpAndSettle();

    expect(selected, isNull);
  });
}
