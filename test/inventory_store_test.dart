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
}
