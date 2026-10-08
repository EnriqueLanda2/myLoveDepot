import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_love_depot/src/inventory_store.dart';
import 'package:my_love_depot/src/models.dart';
import 'package:my_love_depot/src/screens/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<InventoryStore> _loadedStore() async {
  SharedPreferences.setMockInitialValues({});
  final store = InventoryStore();
  await store.load();
  return store;
}

Future<void> _pumpHome(
  WidgetTester tester,
  InventoryStore store,
  Size size,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: HomeScreen(store: store)));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sizes = {
    'teléfono': Size(390, 844),
    'tablet': Size(1280, 800),
  };
  const tabs = ['Resumen', 'Productos', 'Categorías', 'Movimientos', 'Finanzas'];

  for (final entry in sizes.entries) {
    testWidgets('todas las pestañas se dibujan sin errores en ${entry.key}',
        (tester) async {
      final store = await tester.runAsync(_loadedStore);
      await _pumpHome(tester, store!, entry.value);

      for (final tab in tabs) {
        await tester.tap(find.text(tab).last);
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: 'pestaña $tab');
      }
    });
  }

  testWidgets('registra un gasto desde Finanzas', (tester) async {
    final store = await tester.runAsync(_loadedStore);
    await _pumpHome(tester, store!, const Size(390, 844));

    await tester.tap(find.text('Finanzas').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('REGISTRAR GASTO').first);
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.widgetWithText(TextField, 'Monto'), '120,50');
    await tester.tap(find.text('Comida'));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('GUARDAR'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 300));

    final expenses =
        store.movements.where((m) => m.type == MovementType.expense).toList();
    expect(expenses, hasLength(1));
    expect(expenses.single.unitPrice, 120.5);
    expect(expenses.single.note, 'Comida');
    expect(tester.takeException(), isNull);
  });

  testWidgets('el diálogo de ayuda se abre', (tester) async {
    final store = await tester.runAsync(_loadedStore);
    await _pumpHome(tester, store!, const Size(390, 844));

    await tester.tap(find.byTooltip('Ayuda: cómo usar la app'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('¿Cómo usar My Love Depot?'), findsOneWidget);
  });
}
