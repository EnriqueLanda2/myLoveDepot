import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';
import 'models.dart';

/// Error de una operación del store, con un mensaje listo para mostrarse.
class StoreFailure implements Exception {
  const StoreFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

class InventoryStore extends ChangeNotifier {
  static const _productsKey = 'depot_products_v1';
  static const _movementsKey = 'depot_movements_v1';
  static const _categoriesKey = 'depot_categories_v1';
  static const _expensesKey = 'depot_expenses_v1';
  static const _tokenKey = 'depot_auth_token_v1';
  static const _roleKey = 'depot_auth_role_v1';
  static const _walletBaseKey = 'depot_wallet_base_v1';
  static const _weeklyBudgetKey = 'depot_weekly_budget_v1';
  static const _includeSalesKey = 'depot_include_sales_v1';

  /// Cuánto tiempo hay para tocar "Deshacer" antes de borrar en el servidor.
  static const undoWindow = Duration(seconds: 5);

  /// Fondo inicial: el dinero con el que empezaste.
  double walletBaseBalance = 0.0;

  /// Lo máximo que quieres gastar cada semana (lunes a domingo).
  double weeklyBudget = 400.0;

  /// Si es verdadero, las ganancias por ventas se suman al saldo disponible.
  bool includeSalesInBalance = false;

  final List<Product> _products = [];
  final List<StockMovement> _movements = [];
  final List<ProductCategory> _categories = [];
  final List<Expense> _expenses = [];
  late final DepotApiClient api = DepotApiClient(
    onUnauthorized: () {
      logout();
    },
  );
  bool isLoading = true;
  String role = '';
  String username = '';
  String? authError;

  /// Productos cuyo modelo 3D se está generando en el servidor.
  final Set<String> _buildingModels = {};

  /// Borrados en espera: se confirman en el servidor al vencer [undoWindow].
  final Map<String, Timer> _pendingDeletes = {};
  final Map<String, Future<void> Function()> _pendingDeleteActions = {};

  bool get isAuthenticated => api.token.isNotEmpty;

  List<Product> get products => List.unmodifiable(_products);
  List<StockMovement> get movements => List.unmodifiable(_movements);
  List<ProductCategory> get categories => List.unmodifiable(_categories);
  List<Expense> get expenses => List.unmodifiable(_expenses);

  /// Nombres disponibles en el desplegable: los registrados más los que ya
  /// usan los productos, por si el catálogo aún no se sincronizó.
  List<String> get categoryNames {
    final names = <String>{
      for (final category in _categories) category.name,
      for (final product in _products)
        if (product.category.trim().isNotEmpty) product.category.trim(),
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  /// Categorías de gasto ya usadas, de la más reciente a la más antigua.
  List<String> get expenseCategories {
    final seen = <String>{};
    final result = <String>[];
    for (final expense in _expenses) {
      if (seen.add(expense.category.toLowerCase())) {
        result.add(expense.category);
      }
    }
    return result;
  }

  Product? productById(String id) {
    for (final product in _products) {
      if (product.id == id) return product;
    }
    return null;
  }

  bool isBuildingModel(String productId) => _buildingModels.contains(productId);

  // ── Métricas de inventario ────────────────────────────────────────────────

  int get totalUnits => _products.fold(0, (sum, item) => sum + item.stock);
  int get lowStockCount => _products.where((item) => item.hasLowStock).length;
  double get inventoryValue =>
      _products.fold(0, (sum, item) => sum + item.inventoryValue);

  Iterable<StockMovement> _sales(bool Function(DateTime) when) =>
      _movements.where((m) => m.isOutgoing && when(m.createdAt));

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  static bool _sameMonth(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month;

  /// Ganancia = (precio − costo) × cantidad de cada salida de hoy.
  double get todayEarnings => _sales((d) => _sameDay(d, DateTime.now()))
      .fold(0.0, (sum, m) => sum + m.profit);
  double get monthEarnings => _sales((d) => _sameMonth(d, DateTime.now()))
      .fold(0.0, (sum, m) => sum + m.profit);
  int get todaySalesUnits => _sales((d) => _sameDay(d, DateTime.now()))
      .fold(0, (sum, m) => sum + m.quantity);
  int get monthSalesUnits => _sales((d) => _sameMonth(d, DateTime.now()))
      .fold(0, (sum, m) => sum + m.quantity);
  double get totalSalesProfit =>
      _sales((_) => true).fold(0.0, (sum, m) => sum + m.profit);

  // ── Métricas de finanzas ──────────────────────────────────────────────────

  double get totalExpenses => _expenses.fold(0.0, (sum, e) => sum + e.amount);

  /// Saldo = fondo inicial (+ ganancias, si está activado) − gastos totales.
  double get availableBalance =>
      walletBaseBalance +
      (includeSalesInBalance ? totalSalesProfit : 0) -
      totalExpenses;

  /// Lunes 00:00 de la semana de [date].
  static DateTime weekStart(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  double spentInWeek(DateTime start) {
    final end = DateTime(start.year, start.month, start.day + 7);
    return _expenses
        .where((e) => !e.createdAt.isBefore(start) && e.createdAt.isBefore(end))
        .fold(0.0, (sum, e) => sum + e.amount);
  }

  /// Semanas cerradas (anteriores a la actual) desde la del primer gasto.
  List<DateTime> get closedWeeks {
    if (_expenses.isEmpty) return const [];
    final first = weekStart(_expenses
        .map((e) => e.createdAt)
        .reduce((a, b) => a.isBefore(b) ? a : b));
    final current = weekStart(DateTime.now());
    final weeks = <DateTime>[];
    for (var w = first;
        w.isBefore(current);
        w = DateTime(w.year, w.month, w.day + 7)) {
      weeks.add(w);
    }
    return weeks;
  }

  /// Σ (presupuesto − gasto) de las semanas cerradas. Negativo si te excediste.
  double get totalSaved => closedWeeks.fold(
      0.0, (sum, week) => sum + (weeklyBudget - spentInWeek(week)));

  // ── Carga y sesión ────────────────────────────────────────────────────────

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    api.token = preferences.getString(_tokenKey) ?? '';
    role = preferences.getString(_roleKey) ?? '';
    final savedProducts = preferences.getString(_productsKey);
    final savedMovements = preferences.getString(_movementsKey);
    final savedCategories = preferences.getString(_categoriesKey);
    final savedExpenses = preferences.getString(_expensesKey);
    walletBaseBalance = preferences.getDouble(_walletBaseKey) ?? 0.0;
    weeklyBudget = preferences.getDouble(_weeklyBudgetKey) ?? 400.0;
    includeSalesInBalance = preferences.getBool(_includeSalesKey) ?? false;

    if (savedCategories != null) {
      _categories.addAll(
        (jsonDecode(savedCategories) as List).map(
          (item) => ProductCategory.fromJson(item as Map<String, dynamic>),
        ),
      );
    }

    if (savedProducts == null) {
      _products.addAll(_demoProducts);
    } else {
      _products.addAll(
        (jsonDecode(savedProducts) as List).map(
          (item) => Product.fromJson(item as Map<String, dynamic>),
        ),
      );
    }

    if (savedExpenses != null) {
      _expenses.addAll(
        (jsonDecode(savedExpenses) as List).map(
          (item) => Expense.fromJson(item as Map<String, dynamic>),
        ),
      );
    }

    if (savedMovements != null) {
      for (final item in jsonDecode(savedMovements) as List) {
        final movement = StockMovement.fromJson(item as Map<String, dynamic>);
        if (movement.type == MovementType.expense) {
          // Versiones anteriores guardaban los gastos como movimientos y usaban
          // la nota como concepto; pasan a ser gastos con categoría.
          _expenses.add(Expense(
            id: movement.id.startsWith('exp-local-')
                ? 'local-${movement.id.substring(10)}'
                : movement.id.replaceFirst('exp-', ''),
            amount: movement.unitPrice,
            category:
                movement.note.trim().isEmpty ? 'General' : movement.note.trim(),
            createdAt: movement.createdAt,
          ));
        } else {
          _movements.add(movement);
        }
      }
    }
    _expenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await _save();
    isLoading = false;
    notifyListeners();

    if (api.enabled) {
      try {
        await _refreshRemote();
      } on Object catch (error) {
        debugPrint('No se pudo sincronizar el inventario: $error');
      }
    }
    notifyListeners();
  }

  Future<bool> login(String usernameValue, String password) async {
    authError = null;
    if (api.baseUrl.trim().isEmpty) {
      authError = 'La app no tiene servidor configurado. '
          'Compílala con --dart-define=API_BASE_URL=<url de la API>.';
      notifyListeners();
      return false;
    }
    try {
      final data = await api.login(usernameValue.trim(), password);
      role = data['role'] as String;
      username = data['username'] as String;
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(_tokenKey, api.token);
      await preferences.setString(_roleKey, role);
      await _refreshRemote();
      notifyListeners();
      return true;
    } on DepotApiException catch (error) {
      authError = error.statusCode == 401
          ? 'Usuario o contraseña incorrectos.'
          : 'No fue posible iniciar sesión.';
    } on Object {
      authError = 'No hay conexión con el servidor.';
    }
    notifyListeners();
    return false;
  }

  Future<void> logout() async {
    await _flushPendingDeletes();
    api.token = '';
    role = '';
    username = '';
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
    await preferences.remove(_roleKey);
    notifyListeners();
  }

  // ── Ajustes de finanzas ───────────────────────────────────────────────────

  Future<void> setWalletBaseBalance(double value) async {
    walletBaseBalance = math.max(0, value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(_walletBaseKey, walletBaseBalance);
    notifyListeners();
  }

  Future<void> setWeeklyBudget(double value) async {
    weeklyBudget = math.max(0, value);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setDouble(_weeklyBudgetKey, weeklyBudget);
    notifyListeners();
  }

  Future<void> setIncludeSalesInBalance(bool value) async {
    includeSalesInBalance = value;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_includeSalesKey, value);
    notifyListeners();
  }

  // ── Sincronización ────────────────────────────────────────────────────────

  Future<void> _refreshRemote() async {
    final remoteProducts = await api.getProducts();
    // La foto de un producto que aún no se pudo subir se conserva localmente.
    final localById = {for (final product in _products) product.id: product};
    for (final remote in remoteProducts) {
      final local = localById[remote.id];
      if (local != null &&
          remote.imageUrl.isEmpty &&
          local.photoBase64.isNotEmpty) {
        remote.photoBase64 = local.photoBase64;
        remote.pendingImagesBase64 = local.pendingImagesBase64;
      }
    }
    _products
      ..clear()
      ..addAll(remoteProducts
          .where((p) => !_pendingDeletes.containsKey('p:${p.id}')));
    final remoteCategories = await api.getCategories();
    _categories
      ..clear()
      ..addAll(remoteCategories);
    try {
      final remoteMovements = await api.getMovements();
      _movements
        ..clear()
        ..addAll(remoteMovements);
    } on Object catch (error) {
      // Los movimientos remotos son un extra; si falla, se mantienen los locales.
      debugPrint('No se pudieron cargar los movimientos remotos: $error');
    }
    try {
      await _syncExpenses();
    } on Object catch (error) {
      debugPrint('No se pudieron sincronizar los gastos: $error');
    }
    await _save();
  }

  /// Sube los gastos registrados sin conexión y trae la lista del servidor.
  Future<void> _syncExpenses() async {
    for (final expense in _expenses.where((e) => e.isLocal).toList()) {
      expense.id = await api.addExpense(
        amount: expense.amount,
        category: expense.category,
        note: expense.note,
      );
    }
    final remote = await api.getExpenses();
    _expenses
      ..clear()
      ..addAll(remote.where((e) => !_pendingDeletes.containsKey('e:${e.id}')));
  }

  // ── Categorías ────────────────────────────────────────────────────────────

  /// Registra una categoría nueva y devuelve el mensaje de error si falla.
  Future<String?> saveCategory(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Escribe un nombre para la categoría.';
    if (_categories.any(
      (item) => item.name.toLowerCase() == trimmed.toLowerCase(),
    )) {
      return 'Esa categoría ya está registrada.';
    }
    if (!api.enabled) {
      _categories.add(ProductCategory(id: 'local-$trimmed', name: trimmed));
      await _save();
      notifyListeners();
      return null;
    }
    try {
      final created = await api.createCategory(trimmed);
      _categories
        ..removeWhere((item) => item.id == created.id)
        ..add(created);
      await _save();
      notifyListeners();
      return null;
    } on DepotApiException catch (error) {
      return error.reason;
    } on Object {
      return 'No hay conexión con el servidor.';
    }
  }

  Future<String?> renameCategory(ProductCategory category, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'Escribe un nombre para la categoría.';
    if (!api.enabled) return 'Inicia sesión para editar el catálogo.';
    try {
      await api.renameCategory(category.id, trimmed);
      for (final product in _products) {
        if (product.category == category.name) product.category = trimmed;
      }
      await _refreshRemote();
      notifyListeners();
      return null;
    } on DepotApiException catch (error) {
      return error.reason;
    } on Object {
      return 'No hay conexión con el servidor.';
    }
  }

  Future<String?> deleteCategory(ProductCategory category) async {
    // Regla de negocio: una categoría con productos no se puede eliminar.
    final inUse = _products.where((p) => p.category == category.name).length;
    if (inUse > 0) {
      return '“${category.name}” tiene $inUse producto(s). Muévelos antes de eliminarla.';
    }
    if (!api.enabled) {
      _categories.removeWhere((item) => item.id == category.id);
      await _save();
      notifyListeners();
      return null;
    }
    try {
      await api.deleteCategory(category.id);
      await _refreshRemote();
      notifyListeners();
      return null;
    } on DepotApiException catch (error) {
      return error.reason;
    } on Object {
      return 'No hay conexión con el servidor.';
    }
  }

  // ── Productos ─────────────────────────────────────────────────────────────

  /// Pide al servidor reconstruir el modelo 3D a partir de las fotos subidas.
  Future<String?> buildModel(Product product) async {
    if (!api.enabled) return 'Inicia sesión para generar el modelo.';
    if (_buildingModels.contains(product.id)) return null;
    _buildingModels.add(product.id);
    notifyListeners();
    try {
      product.modelUrl = await api.buildProductModel(product.id);
      await _save();
      return null;
    } on DepotApiException catch (error) {
      return error.reason;
    } on Object {
      return 'No hay conexión con el servidor.';
    } finally {
      _buildingModels.remove(product.id);
      notifyListeners();
    }
  }

  Future<String?> saveProduct(Product product) async {
    final index = _products.indexWhere((item) => item.id == product.id);
    if (index == -1) {
      _products.insert(0, product);
    } else {
      _products[index] = product;
    }
    await _save();
    notifyListeners();
    if (api.enabled) {
      try {
        await api.saveProduct(product);
        if (product.pendingImagesBase64.isNotEmpty) {
          final uploaded = <String>[];
          for (var index = 0;
              index < product.pendingImagesBase64.length && index < 5;
              index++) {
            final encoded = product.pendingImagesBase64[index];
            if (encoded.isEmpty) continue;
            uploaded.add(await api.uploadProductImage(
              product.id,
              index,
              base64Decode(encoded),
            ));
          }
          product.pendingImagesBase64 = [];
          if (uploaded.isNotEmpty) {
            product.imageUrl = uploaded.first;
            product.photoBase64 = '';
            await _refreshRemote();
          }
          await _save();
          notifyListeners();
        }
      } on DepotApiException catch (error) {
        debugPrint('El producto quedó local, pendiente de sincronizar: $error');
        return error.reason;
      } on Object catch (error) {
        debugPrint('El producto quedó local, pendiente de sincronizar: $error');
        return 'No hay conexión con el servidor. El producto quedó guardado solo en este dispositivo.';
      }
    }
    return null;
  }

  /// Quita el producto de inmediato y lo borra en el servidor al vencer
  /// [undoWindow]. Devuelve la acción "Deshacer".
  VoidCallback deleteProductWithUndo(Product product) {
    final index = _products.indexWhere((item) => item.id == product.id);
    if (index == -1) return () {};
    final removed = _products.removeAt(index);
    _save();
    notifyListeners();
    return _schedulePendingDelete('p:${product.id}', () async {
      if (!api.enabled) return;
      try {
        await api.deleteProduct(product.id);
      } on Object catch (error) {
        debugPrint('No se pudo eliminar el producto remoto: $error');
      }
    }, undo: () {
      _products.insert(math.min(index, _products.length), removed);
    });
  }

  Future<void> deleteProduct(String id) async {
    final product = productById(id);
    if (product == null) return;
    deleteProductWithUndo(product);
    await _runPendingDelete('p:$id');
  }

  // ── Movimientos ───────────────────────────────────────────────────────────

  Future<String?> moveStock({
    required Product product,
    required MovementType type,
    required int quantity,
    required String note,
  }) async {
    if (quantity <= 0) return 'La cantidad debe ser mayor que cero.';
    // Regla de negocio (también se valida en el servidor): una salida no puede
    // exceder el stock disponible.
    if (type == MovementType.outgoing && quantity > product.stock) {
      return 'Solo hay ${product.stock} en existencia; no puedes sacar $quantity.';
    }

    product.stock += type == MovementType.incoming ? quantity : -quantity;
    _movements.insert(
      0,
      StockMovement(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        productId: product.id,
        productName: product.name,
        productShade: product.shade,
        type: type,
        quantity: quantity,
        createdAt: DateTime.now(),
        unitPrice: product.price,
        unitCost: product.cost,
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
      final serverStock = await api.moveStock(
        product: product,
        type: type,
        quantity: quantity,
        note: note,
      );
      // Corregir el stock local con el valor autoritativo del servidor
      if (product.stock != serverStock) {
        product.stock = serverStock;
        await _save();
        notifyListeners();
      }
    } on Object catch (error) {
      debugPrint(
          'Movimiento guardado localmente, pendiente de sincronizar: $error');
    }
  }

  // ── Gastos ────────────────────────────────────────────────────────────────

  Future<String?> addExpense({
    required double amount,
    required String category,
    String note = '',
  }) async {
    if (amount <= 0) return 'El monto debe ser mayor que cero.';
    final trimmedCategory = category.trim();
    if (trimmedCategory.isEmpty) return 'Elige o escribe una categoría.';
    // Reutiliza la grafía de una categoría ya usada ("farmacia" → "Farmacia").
    final existing = expenseCategories.firstWhere(
      (c) => c.toLowerCase() == trimmedCategory.toLowerCase(),
      orElse: () => trimmedCategory,
    );

    final expense = Expense(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      amount: amount,
      category: existing,
      note: note.trim(),
      createdAt: DateTime.now(),
    );
    _expenses.insert(0, expense);
    await _save();
    notifyListeners();

    if (!api.enabled) return null;
    try {
      expense.id = await api.addExpense(
        amount: expense.amount,
        category: expense.category,
        note: expense.note,
      );
      await _save();
    } on Object catch (error) {
      debugPrint('Gasto guardado localmente, pendiente de sincronizar: $error');
    }
    return null;
  }

  /// Quita el gasto de inmediato y lo borra en el servidor al vencer
  /// [undoWindow]. Devuelve la acción "Deshacer".
  VoidCallback deleteExpenseWithUndo(Expense expense) {
    final index = _expenses.indexOf(expense);
    if (index == -1) return () {};
    _expenses.removeAt(index);
    _save();
    notifyListeners();
    return _schedulePendingDelete('e:${expense.id}', () async {
      if (!api.enabled || expense.isLocal) return;
      try {
        await api.deleteExpense(expense.id);
      } on Object catch (error) {
        debugPrint('No se pudo eliminar el gasto remoto: $error');
      }
    }, undo: () {
      _expenses
        ..insert(math.min(index, _expenses.length), expense)
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  VoidCallback _schedulePendingDelete(
    String key,
    Future<void> Function() commit, {
    required VoidCallback undo,
  }) {
    _pendingDeletes[key]?.cancel();
    _pendingDeleteActions[key] = commit;
    _pendingDeletes[key] = Timer(undoWindow, () => _runPendingDelete(key));
    return () {
      final timer = _pendingDeletes.remove(key);
      if (timer == null) return; // Ya se confirmó.
      timer.cancel();
      _pendingDeleteActions.remove(key);
      undo();
      _save();
      notifyListeners();
    };
  }

  Future<void> _runPendingDelete(String key) async {
    _pendingDeletes.remove(key)?.cancel();
    final action = _pendingDeleteActions.remove(key);
    if (action != null) await action();
  }

  Future<void> _flushPendingDeletes() async {
    for (final key in _pendingDeletes.keys.toList()) {
      await _runPendingDelete(key);
    }
  }

  // ── IA ────────────────────────────────────────────────────────────────────

  Future<T> _aiCall<T>(Future<T> Function() call) async {
    if (!api.enabled) {
      throw const StoreFailure(
          'Inicia sesión con el servidor para usar la IA.');
    }
    try {
      return await call();
    } on DepotApiException catch (error) {
      throw StoreFailure(error.reason);
    } on TimeoutException {
      throw const StoreFailure(
          'La IA tardó demasiado en responder. Intenta de nuevo.');
    } on Object {
      throw const StoreFailure('No hay conexión con el servidor.');
    }
  }

  /// La IA identifica el producto de la foto y propone nombre, tono,
  /// categoría, descripción y etiquetas.
  Future<AiProductSuggestion> analyzeProductPhoto(Uint8List bytes) =>
      _aiCall(() => api.analyzeProduct(bytes));

  /// Cuatro fotografías de catálogo hechas a partir de la foto base.
  Future<List<AiPhotoOption>> generateProductPhotos(Uint8List bytes,
          {int set = 0}) =>
      _aiCall(() => api.generateProductPhotos(bytes, set: set));

  // ── Persistencia local ────────────────────────────────────────────────────

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
    await preferences.setString(
      _categoriesKey,
      jsonEncode(_categories.map((item) => item.toJson()).toList()),
    );
    await preferences.setString(
      _expensesKey,
      jsonEncode(_expenses.map((item) => item.toJson()).toList()),
    );
  }

  @override
  void dispose() {
    for (final timer in _pendingDeletes.values) {
      timer.cancel();
    }
    super.dispose();
  }

  static List<Product> get _demoProducts => [
        Product(
          id: 'demo-1',
          name: 'Valentino Donna Born in Roma',
          shade: 'Eau de Parfum · 50 ml',
          sku: 'VAL-001',
          category: 'Mujer',
          price: 450.00,
          cost: 320.00,
          stock: 0,
          minimumStock: 2,
          imageUrl:
              'https://images.unsplash.com/photo-1541643600914-78b084683601?w=600&auto=format&fit=crop&q=80',
        ),
        Product(
          id: 'demo-2',
          name: 'Bad Boy',
          shade: 'Superstars · 100 ml',
          sku: 'CH-002',
          category: 'Hombre',
          price: 550.00,
          cost: 390.00,
          stock: 0,
          minimumStock: 2,
          imageUrl:
              'https://images.unsplash.com/photo-1523293182086-7651a899d37f?w=600&auto=format&fit=crop&q=80',
        ),
        Product(
          id: 'demo-3',
          name: 'Invictus',
          shade: 'Eau de Toilette · 100 ml',
          sku: 'PR-003',
          category: 'Hombre',
          price: 450.00,
          cost: 300.00,
          stock: 1,
          minimumStock: 1,
          imageUrl:
              'https://images.unsplash.com/photo-1594035910387-fea47794261f?w=600&auto=format&fit=crop&q=80',
        ),
        Product(
          id: 'demo-4',
          name: 'Sauvage',
          shade: 'Eau de Parfum · 60 ml',
          sku: 'DIOR-004',
          category: 'Hombre',
          price: 450.00,
          cost: 310.00,
          stock: 3,
          minimumStock: 2,
          imageUrl:
              'https://images.unsplash.com/photo-1592945403244-b3fbafd7f539?w=600&auto=format&fit=crop&q=80',
        ),
        Product(
          id: 'demo-5',
          name: 'Valentino Donna',
          shade: 'Coral Fantasy · 50 ml',
          sku: 'VAL-005',
          category: 'Mujer',
          price: 450.00,
          cost: 320.00,
          stock: 2,
          minimumStock: 1,
          imageUrl:
              'https://images.unsplash.com/photo-1588405748880-12d1d2a59f75?w=600&auto=format&fit=crop&q=80',
        ),
        Product(
          id: 'demo-6',
          name: 'Santal 33',
          shade: 'Eau de Parfum · 50 ml',
          sku: 'LEL-006',
          category: 'Unisex',
          price: 550.00,
          cost: 400.00,
          stock: 4,
          minimumStock: 1,
          imageUrl:
              'https://images.unsplash.com/photo-1594035910387-fea47794261f?w=600&auto=format&fit=crop&q=80',
        ),
      ];
}
