import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_love_depot/src/inventory_store.dart';
import 'package:my_love_depot/src/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('detecta stock bajo y calcula el valor del producto', () {
    final product = Product(
      id: '1',
      name: 'Producto',
      sku: 'SKU-1',
      category: 'General',
      price: 25,
      stock: 3,
      minimumStock: 5,
    );

    expect(product.hasLowStock, isTrue);
    expect(product.inventoryValue, 75);
  });

  test('el modelo 3D viaja en el JSON del producto', () {
    final product = Product.fromJson({
      'id': '1',
      'name': 'Producto',
      'sku': 'SKU-1',
      'category': 'General',
      'price': 10,
      'stock': 1,
      'minimumStock': 0,
      'modelUrl': 'https://ejemplo/model.glb',
    });

    expect(product.modelUrl, 'https://ejemplo/model.glb');
    expect(Product.fromJson(product.toJson()).modelUrl, product.modelUrl);
  });

  test('registra categorías y las ordena sin distinguir mayúsculas', () async {
    final store = InventoryStore();

    expect(await store.saveCategory('Organización'), isNull);
    expect(await store.saveCategory('  empaque  '), isNull);

    expect(store.categoryNames, ['empaque', 'Organización']);
    expect(store.categories.map((item) => item.name), contains('empaque'));
  });

  test('rechaza categorías repetidas y vacías', () async {
    final store = InventoryStore();
    await store.saveCategory('Papelería');

    expect(await store.saveCategory('papelería'), isNotNull);
    expect(await store.saveCategory('   '), isNotNull);
    expect(store.categoryNames, ['Papelería']);
  });

  test('el desplegable incluye categorías que ya usan los productos', () async {
    final store = InventoryStore();
    await store.saveCategory('Empaque');
    await store.saveProduct(Product(
      id: '9',
      name: 'Cinta',
      sku: 'CIN-1',
      category: 'Adhesivos',
      price: 10,
      stock: 1,
      minimumStock: 0,
    ));

    expect(store.categoryNames, ['Adhesivos', 'Empaque']);
  });

  Product sample({int stock = 3}) => Product(
        id: 'p1',
        name: 'Glossy Lip Oil',
        sku: 'LIP-1',
        category: 'Makeup',
        shade: 'Coral',
        price: 120,
        cost: 70,
        stock: stock,
        minimumStock: 1,
      );

  test('la ganancia de una venta es (precio − costo) × cantidad', () async {
    final store = InventoryStore();
    final product = sample();
    await store.saveProduct(product);

    expect(
      await store.moveStock(
          product: product, type: MovementType.outgoing, quantity: 2, note: 'Venta'),
      isNull,
    );
    expect(product.stock, 1);
    expect(store.todayEarnings, 100);
    expect(store.todaySalesUnits, 2);
    // El precio y el costo quedan congelados en el movimiento.
    product.price = 999;
    expect(store.movements.first.profit, 100);
  });

  test('una salida no puede exceder el stock disponible', () async {
    final store = InventoryStore();
    final product = sample(stock: 1);
    await store.saveProduct(product);

    expect(
      await store.moveStock(
          product: product, type: MovementType.outgoing, quantity: 2, note: ''),
      isNotNull,
    );
    expect(product.stock, 1);
    expect(store.movements, isEmpty);
  });

  test('no se elimina una categoría que tiene productos', () async {
    final store = InventoryStore();
    await store.saveCategory('Makeup');
    await store.saveProduct(sample());

    expect(await store.deleteCategory(store.categories.single), isNotNull);
    expect(store.categories, hasLength(1));
  });

  test('deshacer devuelve el producto y el gasto eliminados', () async {
    final store = InventoryStore();
    await store.saveProduct(sample());
    await store.addExpense(amount: 50, category: 'Farmacia');

    store.deleteProductWithUndo(store.products.single)();
    store.deleteExpenseWithUndo(store.expenses.single)();

    expect(store.products, hasLength(1));
    expect(store.expenses, hasLength(1));
  });

  test('las semanas van de lunes a domingo', () {
    // 8 de octubre de 2026 es jueves.
    expect(InventoryStore.weekStart(DateTime(2026, 10, 8, 15)), DateTime(2026, 10, 5));
    expect(InventoryStore.weekStart(DateTime(2026, 10, 11, 23)), DateTime(2026, 10, 5));
    expect(InventoryStore.weekStart(DateTime(2026, 10, 12)), DateTime(2026, 10, 12));
  });

  test('saldo = fondo − gastos, y suma ventas solo si se activa', () async {
    final store = InventoryStore();
    final product = sample();
    await store.saveProduct(product);
    await store.setWalletBaseBalance(1000);
    await store.addExpense(amount: 150, category: 'Comida');
    await store.moveStock(
        product: product, type: MovementType.outgoing, quantity: 1, note: '');

    expect(store.availableBalance, 850);
    await store.setIncludeSalesInBalance(true);
    expect(store.availableBalance, 900);
  });

  test('los gastos viejos guardados como movimientos pasan a tener categoría', () async {
    SharedPreferences.setMockInitialValues({
      'depot_products_v1': '[]',
      'depot_movements_v1': jsonEncode([
        {
          'id': 'exp-local-123',
          'productId': '',
          'productName': 'Gasto Personal',
          'type': 'expense',
          'quantity': 1,
          'createdAt': DateTime(2026, 10, 1).toIso8601String(),
          'unitPrice': 89.5,
          'note': 'Farmacia',
        },
      ]),
    });
    final store = InventoryStore();
    await store.load();

    expect(store.movements, isEmpty);
    expect(store.expenses.single.category, 'Farmacia');
    expect(store.expenses.single.amount, 89.5);
    expect(store.expenses.single.isLocal, isTrue);
  });
}

