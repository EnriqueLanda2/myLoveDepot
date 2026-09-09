enum MovementType { incoming, outgoing }

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

  factory ProductCategory.fromJson(Map<String, dynamic> json) => ProductCategory(
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
    this.barcode = '',
    this.photoBase64 = '',
    this.imageUrl = '',
    this.modelUrl = '',
    this.originalPrice,
    this.wholesalePrice,
    this.mediaType,
    List<String>? imageUrls,
    List<String>? pendingImagesBase64,
  })  : imageUrls = imageUrls ?? [],
        pendingImagesBase64 = pendingImagesBase64 ?? [];

  final String id;
  String name;
  String sku;
  String category;
  double price;
  int stock;
  int minimumStock;
  String barcode;
  String photoBase64;
  String imageUrl;
  String modelUrl;
  double? originalPrice;
  double? wholesalePrice;
  String? mediaType;
  List<String> imageUrls;
  List<String> pendingImagesBase64;

  bool get hasLowStock => stock <= minimumStock;
  double get inventoryValue => stock * price;

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

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sku': sku,
        'category': category,
        'price': price,
        'stock': stock,
        'minimumStock': minimumStock,
        'barcode': barcode,
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
        price: (json['price'] as num).toDouble(),
        stock: json['stock'] as int,
        minimumStock: json['minimumStock'] as int,
        barcode: json['barcode'] as String? ?? '',
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
    this.unitPrice = 0.0,
    this.note = '',
  });

  final String id;
  final String productId;
  final String productName;
  final MovementType type;
  final int quantity;
  final DateTime createdAt;
  final double unitPrice;
  final String note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'productName': productName,
        'type': type.name,
        'quantity': quantity,
        'createdAt': createdAt.toIso8601String(),
        'unitPrice': unitPrice,
        'note': note,
      };

  factory StockMovement.fromJson(Map<String, dynamic> json) => StockMovement(
        id: json['id'] as String,
        productId: json['productId'] as String,
        productName: json['productName'] as String,
        type: MovementType.values.byName(json['type'] as String),
        quantity: json['quantity'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
        unitPrice: (json['unitPrice'] as num?)?.toDouble() ?? 0.0,
        note: json['note'] as String? ?? '',
      );
}
