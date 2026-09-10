import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pos/shared/feature_ui.dart';

Widget _host(double width) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            child: const ScrollableTable(
              flexColumn: 1,
              columns: [
                DataColumn(label: Text('A')),
                DataColumn(label: Text('B')),
                DataColumn(label: Text('C')),
              ],
              rows: [
                DataRow(cells: [
                  DataCell(Text('1')),
                  DataCell(Text('two')),
                  DataCell(Text('3')),
                ]),
              ],
            ),
          ),
        ),
      ),
    );

void main() {
  testWidgets('table fills its slot and grows when the slot widens',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_host(500));
    await tester.pumpAndSettle();
    final narrow = tester.getSize(find.byType(DataTable)).width;
    expect(narrow, closeTo(500, 1));

    // Simulate the sidebar collapsing: the content slot gets wider.
    await tester.pumpWidget(_host(900));
    await tester.pumpAndSettle();
    final wide = tester.getSize(find.byType(DataTable)).width;
    expect(wide, closeTo(900, 1));
    expect(wide, greaterThan(narrow));
  });
}
