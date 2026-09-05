// Mode grid: six toggles in one row on a phone width, wrapping beyond six,
// 44 pt targets, selected/unselected styling, toggle callback and semantics.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:opentransit_mobile/core/widgets/mode_grid.dart';

void main() {
  List<ModeGridItem> items(int n, Set<String> selected, void Function(String, bool) onToggle) => [
        for (var i = 0; i < n; i++)
          ModeGridItem(
            id: 'm$i',
            label: ['Bus', 'Cable', 'Bici', 'A pie', 'Pública', 'Taxi/app', 'Tren'][i],
            icon: Icons.directions_bus,
            selected: selected.contains('m$i'),
            color: const Color(0xFFD32F2F),
            onToggle: (v) => onToggle('m$i', v),
          ),
      ];

  Widget host(Widget child, {double width = 390}) => MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: Padding(padding: const EdgeInsets.all(16), child: child)),
          ),
        ),
      );

  testWidgets('six toggles fit in one row at 390 pt, each ≥ 52 wide and 44 tall', (tester) async {
    await tester.pumpWidget(host(ModeGrid(items: items(6, {'m0'}, (_, _) {}), onLabel: 'activado', offLabel: 'desactivado')));
    await tester.pumpAndSettle();
    final tops = <double>{};
    for (var i = 0; i < 6; i++) {
      final r = tester.getRect(find.byKey(ValueKey('mode-m$i')));
      tops.add(r.top.roundToDouble());
      expect(r.width, greaterThanOrEqualTo(52));
      expect(r.height, 44);
    }
    expect(tops, hasLength(1), reason: 'all six on one row');
  });

  testWidgets('seven toggles wrap to a second row at 375 pt', (tester) async {
    await tester.pumpWidget(host(ModeGrid(items: items(7, {}, (_, _) {}), onLabel: 'on', offLabel: 'off'), width: 375));
    await tester.pumpAndSettle();
    final tops = {for (var i = 0; i < 7; i++) tester.getRect(find.byKey(ValueKey('mode-m$i'))).top.roundToDouble()};
    expect(tops, hasLength(2));
  });

  testWidgets('tapping toggles with the inverse of the current state; semantics say the state', (tester) async {
    final calls = <String>[];
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(host(ModeGrid(items: items(2, {'m0'}, (id, v) => calls.add('$id:$v')), onLabel: 'activado', offLabel: 'desactivado')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mode-m0')));
    await tester.tap(find.byKey(const ValueKey('mode-m1')));
    expect(calls, ['m0:false', 'm1:true']);
    final on = tester.getSemantics(find.byKey(const ValueKey('mode-m0')));
    expect(on.label, 'Bus, activado');
    expect(on.flagsCollection.isSelected.name, 'isTrue');
    final off = tester.getSemantics(find.byKey(const ValueKey('mode-m1')));
    expect(off.label, 'Cable, desactivado');
    handle.dispose();
  });

  testWidgets('selected toggles are filled, unselected are outlined', (tester) async {
    await tester.pumpWidget(host(ModeGrid(items: items(2, {'m0'}, (_, _) {}), onLabel: 'on', offLabel: 'off')));
    await tester.pumpAndSettle();
    Material materialOf(String id) =>
        tester.widget<Material>(find.descendant(of: find.byKey(ValueKey(id)), matching: find.byType(Material)).first);
    expect(materialOf('mode-m0').color, isNot(Colors.transparent));
    expect(materialOf('mode-m1').color, Colors.transparent);
  });
}
