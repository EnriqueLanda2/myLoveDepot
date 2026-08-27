import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'models.dart';

class InventoryStore extends ChangeNotifier {
  static const _productsKey = 'depot_products_v1';
  static const _movementsKey = 'depot_movements_v1';

  final List<Product> _products = [];
  final List<StockMovement> _movements = [];
  final DepotApiClient api = DepotApiClient();
  bool isLoading = true;

  List<Product> get products => List.unmodifiable(_products);
  List<StockMovement> get movements => List.unmodifiable(_movements);
  int get totalUnits => _products.fold(0, (sum, item) => sum + item.stock);
  int get lowStockCount => _products.where((item) => item.hasLowStock).length;
  double get inventoryValue =>
      _products.fold(0, (sum, item) => sum + item.inventoryValue);

  Product? findByBarcode(String barcode) {
    final normalized = barcode.trim();
    if (normalized.isEmpty) return null;
    for (final product in _products) {
      if (product.barcode == normalized) return product;
    }
    return null;
  }

  bool barcodeBelongsToAnotherProduct(String barcode, String? productId) {
    final match = findByBarcode(barcode);
    return match != null && match.id != productId;
  }

  Future<void> addOne(Product product) async {
    product.stock += 1;
    _movements.insert(
      0,
      StockMovement(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        productId: product.id,
        productName: product.name,
        type: MovementType.incoming,
        quantity: 1,
        createdAt: DateTime.now(),
        note: 'Escaneo de código',
      ),
    );
    await _save();
    notifyListeners();
    await _syncMovement(
      product: product,
      type: MovementType.incoming,
      quantity: 1,
      note: 'Escaneo de código',
    );
  }

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    final savedProducts = preferences.getString(_productsKey);
    final savedMovements = preferences.getString(_movementsKey);

    if (savedProducts == null) {
      _products.addAll(_demoProducts);
      await _save();
    } else {
      _products.addAll(
        (jsonDecode(savedProducts) as List).map(
          (item) => Product.fromJson(item as Map<String, dynamic>),
        ),
      );
    }

    if (savedMovements != null) {
      _movements.addAll(
        (jsonDecode(savedMovements) as List).map(
          (item) => StockMovement.fromJson(item as Map<String, dynamic>),
        ),
      );
    }
    isLoading = false;
    notifyListeners();

    if (api.enabled) {
      try {
        final remoteProducts = await api.getProducts();
        _products
          ..clear()
          ..addAll(remoteProducts);
        await _save();
      } on Object catch (error) {
        debugPrint('No se pudo sincronizar el inventario: $error');
      }
    }
    notifyListeners();
  }

  Future<void> saveProduct(Product product) async {
    final index = _products.indexWhere((item) => item.id == product.id);
    if (index == -1) {
      _products.add(product);
    } else {
      _products[index] = product;
    }
    await _save();
    notifyListeners();
    if (api.enabled) {
      try {
        await api.saveProduct(product);
        if (product.photoBase64.isNotEmpty) {
          product.imageUrl = await api.uploadProductImage(
            product.id,
            base64Decode(product.photoBase64),
          );
          product.photoBase64 = '';
          await _save();
        }
      } on Object catch (error) {
        debugPrint('El producto quedó local, pendiente de sincronizar: $error');
      }
    }
  }

  Future<void> deleteProduct(String id) async {
    _products.removeWhere((item) => item.id == id);
    await _save();
    notifyListeners();
    if (api.enabled) {
      try {
        await api.deleteProduct(id);
      } on Object catch (error) {
        debugPrint('No se pudo eliminar el producto remoto: $error');
      }
    }
  }

  Future<String?> moveStock({
    required Product product,
    required MovementType type,
    required int quantity,
    required String note,
  }) async {
    if (quantity <= 0) return 'La cantidad debe ser mayor que cero.';
    if (type == MovementType.outgoing && quantity > product.stock) {
      return 'No hay existencias suficientes para realizar la salida.';
    }

    product.stock += type == MovementType.incoming ? quantity : -quantity;
    _movements.insert(
      0,
      StockMovement(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        productId: product.id,
        productName: product.name,
        type: type,
        quantity: quantity,
        createdAt: DateTime.now(),
        note: note,
      ),
    );
    await _save();
    notifyListeners();
    await _syncMovement(
      product: product,
      type: type,
      quantity: quantity,
      note: note,
    );
    return null;
  }

  Future<void> _syncMovement({
    required Product product,
    required MovementType type,
    required int quantity,
    required String note,
  }) async {
    if (!api.enabled) return;
    try {
      await api.moveStock(
        product: product,
        type: type,
        quantity: quantity,
        note: note,
      );
    } on Object catch (error) {
      debugPrint(
          'Movimiento guardado localmente, pendiente de sincronizar: $error');
    }
  }

  Future<void> _save() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _productsKey,
      jsonEncode(_products.map((item) => item.toJson()).toList()),
    );
    await preferences.setString(
      _movementsKey,
      jsonEncode(_movements.map((item) => item.toJson()).toList()),
    );
  }

  static List<Product> get _demoProducts => [
        Product(
          id: 'demo-1',
          name: 'Caja organizadora',
          sku: 'ORG-001',
          category: 'Organización',
          price: 249.90,
          stock: 18,
          minimumStock: 5,
        ),
        Product(
          id: 'demo-2',
          name: 'Cinta para empaque',
          sku: 'EMP-014',
          category: 'Empaque',
          price: 42.50,
          stock: 4,
          minimumStock: 8,
        ),
        Product(
          id: 'demo-3',
          name: 'Etiqueta adhesiva',
          sku: 'ETQ-120',
          category: 'Papelería',
          price: 79,
          stock: 35,
          minimumStock: 10,
        ),
      ];
}
