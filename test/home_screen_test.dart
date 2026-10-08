import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_love_depot/src/app.dart';
import 'package:my_love_depot/src/inventory_store.dart';
import 'package:my_love_depot/src/screens/home_screen.dart';
import 'package:my_love_depot/src/ui/components.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<InventoryStore> _loadedStore() async {
  SharedPreferences.setMockInitialValues({});
  final store = InventoryStore();
  await store.load();
  return store;
}

Future<void> _pumpHome(WidgetTester tester, InventoryStore store, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: buildAppTheme(), home: HomeScreen(store: store)));
  await tester.pump(const Duration(milliseconds: 300));
}

/// Deja vencer el aviso inferior (y su temporizador) antes de terminar.
Future<void> _settleToast(WidgetTester tester) => tester.pump(const Duration(seconds: 5));

/// Las pruebas usan por omisión una fuente de bloques más ancha que la real;
/// con Figtree los desbordes que se detectan son los que vería el usuario.
Future<void> _loadFigtree() async {
  final loader = FontLoader('Figtree');
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/Figtree-$weight.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFigtree);

  const sizes = {
    'teléfono chico': Size(320, 640),
    'teléfono': Size(390, 844),
    'tablet': Size(1280, 800),
  };
  const tabs = ['Resumen', 'Productos', 'Categorías', 'Movimientos', 'Finanzas'];

  for (final entry in sizes.entries) {
    testWidgets('todas las vistas se dibujan sin errores en ${entry.key}', (tester) async {
      final store = await tester.runAsync(_loadedStore);
      await _pumpHome(tester, store!, entry.value);

      for (final tab in tabs) {
        await tester.tap(find.text(tab).last);
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull, reason: 'vista $tab');
      }
    });

    testWidgets('el modal de nuevo producto se dibuja en ${entry.key}', (tester) async {
      final store = await tester.runAsync(_loadedStore);
      await _pumpHome(tester, store!, entry.value);

      await tester.tap(find.byTooltip('Nuevo producto').evaluate().isNotEmpty
          ? find.byTooltip('Nuevo producto')
          : find.text('Nuevo producto').first);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Agregar al catálogo'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('registra un gasto con categoría desde Finanzas', (tester) async {
    final store = await tester.runAsync(_loadedStore);
    await _pumpHome(tester, store!, const Size(1280, 800));

    await tester.tap(find.text('Finanzas').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Registrar gasto').first);
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(
        find.descendant(of: find.byType(AmountField), matching: find.byType(TextField)), '120,50');
    await tester.enterText(find.widgetWithText(TextField, 'Ej. Comida, Farmacia, Transporte'), 'Comida');
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.text('Guardar gasto'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump(const Duration(milliseconds: 300));

    expect(store.expenses, hasLength(1));
    expect(store.expenses.single.amount, 120.5);
    expect(store.expenses.single.category, 'Comida');
    expect(find.text('Gasto registrado'), findsOneWidget);
    await _settleToast(tester);
  });

  testWidgets('agrega un producto a mano con nombre y precio', (tester) async {
    final store = await tester.runAsync(_loadedStore);
    await _pumpHome(tester, store!, const Size(1280, 800));
    final before = store.products.length;

    await tester.tap(find.text('Nuevo producto').first);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.widgetWithText(TextField, 'Ej. Elf Halo Glow Beauty Wand Blush'), 'Glossy Lip Oil');
    await tester.enterText(find.widgetWithText(TextField, '\$0').first, '120');
    await tester.enterText(find.widgetWithText(TextField, '\$0').last, '70');
    await tester.pump();
    expect(find.textContaining('Ganas \$50.00 por unidad'), findsOneWidget);

    await tester.runAsync(() async {
      await tester.tap(find.text('Agregar al catálogo'));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pump(const Duration(milliseconds: 300));

    expect(store.products, hasLength(before + 1));
    final created = store.products.firstWhere((p) => p.name == 'Glossy Lip Oil');
    expect(created.price, 120);
    expect(created.cost, 70);
    expect(created.sku, isNotEmpty);
    await _settleToast(tester);
  });

  testWidgets('la ayuda se abre desde el sidebar', (tester) async {
    final store = await tester.runAsync(_loadedStore);
    await _pumpHome(tester, store!, const Size(1280, 800));

    await tester.tap(find.text('Ayuda'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('¿Cómo usar My Love Depot?'), findsOneWidget);
  });
}
