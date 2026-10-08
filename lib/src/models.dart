enum MovementType { incoming, outgoing, expense }

/// Categoría registrada del catálogo. Se llama así, y no `Category`, porque
/// `flutter/foundation` ya exporta una anotación con ese nombre.
class ProductCategory {
  const ProductCategory({
    required this.id,
    required this.name,
    this.productCount = 0,
  });

  final String id;
  final String name;
  final int productCount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'productCount': productCount,
      };

  factory ProductCategory.fromJson(Map<String, dynamic> json) =>
      ProductCategory(
        id: json['id'] as String,
        name: json['name'] as String,
        productCount: (json['productCount'] as num?)?.toInt() ?? 0,
      );
}

class Product {
  Product({
    required this.id,
    required this.name,
    required this.sku,
    required this.category,
    required this.price,
    required this.stock,
    required this.minimumStock,
    this.shade = '',
    this.cost = 0,
    this.description = '',
    List<String>? tags,
    this.photoBase64 = '',
    this.imageUrl = '',
    this.modelUrl = '',
    this.originalPrice,
    this.wholesalePrice,
    this.mediaType,
    List<String>? imageUrls,
    List<String>? pendingImagesBase64,
  })  : tags = tags ?? [],
        imageUrls = imageUrls ?? [],
        pendingImagesBase64 = pendingImagesBase64 ?? [];

  final String id;
  String name;
  String sku;
  String category;
  double price;
  int stock;
  int minimumStock;

  /// Tono, aroma, tamaño o variante (p. ej. "Rosé you slay", "50 ml").
  String shade;

  /// Lo que cuesta comprar una unidad. La ganancia de una venta es
  /// (precio − costo) × cantidad.
  double cost;
  String description;
  List<String> tags;
  String photoBase64;
  String imageUrl;
  String modelUrl;
  double? originalPrice;
  double? wholesalePrice;
  String? mediaType;
  List<String> imageUrls;
  List<String> pendingImagesBase64;

  bool get hasLowStock => stock <= minimumStock;
  bool get isOutOfStock => stock <= 0;
  double get inventoryValue => stock * price;
  double get unitProfit => price - cost;

  bool get isVideo {
    if (mediaType == 'video') return true;
    final url = imageUrl.toLowerCase();
    return url.endsWith('.mp4') ||
        url.endsWith('.webm') ||
        url.endsWith('.mov') ||
        url.contains('/video/');
  }

  /// Precio anterior tachado (si no fue especificado, calcula aprox. un 22-25% más para el badge)
  double get effectiveOriginalPrice {
    if (originalPrice != null && originalPrice! > price) {
      return originalPrice!;
    }
    return (price * 1.25).roundToDouble();
  }

  /// Precio de mayoreo (si no fue especificado, calcula aprox. un 12% menor)
  double get effectiveWholesalePrice {
    if (wholesalePrice != null && wholesalePrice! > 0) {
      return wholesalePrice!;
    }
    return (price * 0.88).roundToDouble();
  }

  /// Porcentaje de descuento para el badge negro de la esquina superior izquierda
  int get discountPercent {
    final orig = effectiveOriginalPrice;
    if (orig > price && orig > 0) {
      return (((orig - price) / orig) * 100).round();
    }
    return 20;
  }

  Product copy() => Product.fromJson(toJson());

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sku': sku,
        'category': category,
        'shade': shade,
        'price': price,
        'cost': cost,
        'stock': stock,
        'minimumStock': minimumStock,
        'description': description,
        'tags': tags,
        'photoBase64': photoBase64,
        'imageUrl': imageUrl,
        'modelUrl': modelUrl,
        'originalPrice': originalPrice,
        'wholesalePrice': wholesalePrice,
        'mediaType': mediaType,
        'imageUrls': imageUrls,
        'pendingImagesBase64': pendingImagesBase64,
      };

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'] as String,
        name: json['name'] as String,
        sku: json['sku'] as String,
        category: json['category'] as String,
        shade: json['shade'] as String? ?? '',
        price: (json['price'] as num).toDouble(),
        cost: (json['cost'] as num?)?.toDouble() ?? 0,
        stock: (json['stock'] as num).toInt(),
        minimumStock: (json['minimumStock'] as num).toInt(),
        description: json['description'] as String? ?? '',
        tags: (json['tags'] as List? ?? []).cast<String>(),
        photoBase64: json['photoBase64'] as String? ?? '',
        imageUrl: json['imageUrl'] as String? ?? '',
        modelUrl: json['modelUrl'] as String? ?? '',
        originalPrice: (json['originalPrice'] as num?)?.toDouble(),
        wholesalePrice: (json['wholesalePrice'] as num?)?.toDouble(),
        mediaType: json['mediaType'] as String?,
        imageUrls: (json['imageUrls'] as List? ?? []).cast<String>(),
        pendingImagesBase64:
            (json['pendingImagesBase64'] as List? ?? []).cast<String>(),
      );
}

class StockMovement {
  StockMovement({
    required this.id,
    required this.productId,
    required this.productName,
    required this.type,
    required this.quantity,
    required this.createdAt,
    this.productShade = '',
    this.unitPrice = 0.0,
    this.unitCost = 0.0,
    this.note = '',
  });

  final String id;
  final String productId;
  final String productName;
  final String productShade;
  final MovementType type;
  final int quantity;
  final DateTime createdAt;

  /// Precio y costo del producto al momento del movimiento: la ganancia de una
  /// venta no cambia si después se edita el producto.
  final double unitPrice;
  final double unitCost;
  final String note;

  bool get isOutgoing => type == MovementType.outgoing;
  double get profit => isOutgoing ? (unitPrice - unitCost) * quantity : 0;

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'productName': productName,
        'productShade': productShade,
        'type': type.name,
        'quantity': quantity,
        'createdAt': createdAt.toIso8601String(),
        'unitPrice': unitPrice,
        'unitCost': unitCost,
        'note': note,
      };

  factory StockMovement.fromJson(Map<String, dynamic> json) => StockMovement(
        id: json['id'].toString(),
        productId: json['productId'] as String,
        productName: json['productName'] as String? ?? '',
        productShade: json['productShade'] as String? ?? '',
        type: MovementType.values.byName(json['type'] as String),
        quantity: (json['quantity'] as num).toInt(),
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
        unitCost: (json['unitCost'] as num?)?.toDouble() ?? 0.0,
        note: json['note'] as String? ?? '',
      );
}

/// Gasto personal (Finanzas). Va aparte de los movimientos de inventario.
class Expense {
  Expense({
    required this.id,
    required this.amount,
    required this.category,
    required this.createdAt,
    this.note = '',
  });

  /// Id del servidor, o `local-…` mientras no se ha sincronizado.
  String id;
  final double amount;
  final String category;
  final String note;
  final DateTime createdAt;

  bool get isLocal => id.startsWith('local-');

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'category': category,
        'note': note,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'].toString(),
        amount: (json['amount'] as num).toDouble(),
        category: json['category'] as String? ?? 'General',
        note: json['note'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      );
}

/// Ficha que la IA propone a partir de la foto del producto.
class AiProductSuggestion {
  const AiProductSuggestion({
    required this.name,
    required this.brand,
    required this.shade,
    required this.category,
    required this.description,
    required this.tags,
    required this.confidence,
  });

  final String name;
  final String brand;
  final String shade;
  final String category;
  final String description;
  final List<String> tags;
  final double confidence;

  factory AiProductSuggestion.fromJson(Map<String, dynamic> json) =>
      AiProductSuggestion(
        name: json['name'] as String? ?? '',
        brand: json['brand'] as String? ?? '',
        shade: json['shade'] as String? ?? '',
        category: json['category'] as String? ?? '',
        description: json['description'] as String? ?? '',
        tags: (json['tags'] as List? ?? []).cast<String>(),
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      );
}

/// Una de las fotografías de catálogo generadas a partir de la foto base.
class AiPhotoOption {
  const AiPhotoOption({required this.label, required this.bytesBase64});

  final String label;

  /// JPEG en Base64 (sin el prefijo `data:`).
  final String bytesBase64;
}
