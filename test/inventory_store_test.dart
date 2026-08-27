import 'package:flutter_test/flutter_test.dart';
import 'package:my_love_depot/src/models.dart';

void main() {
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
}
