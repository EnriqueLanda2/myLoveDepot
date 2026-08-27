enum MovementType { incoming, outgoing }

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
  });

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

  bool get hasLowStock => stock <= minimumStock;
  double get inventoryValue => stock * price;

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
    this.note = '',
  });

  final String id;
  final String productId;
  final String productName;
  final MovementType type;
  final int quantity;
  final DateTime createdAt;
  final String note;

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'productName': productName,
        'type': type.name,
        'quantity': quantity,
        'createdAt': createdAt.toIso8601String(),
        'note': note,
      };

  factory StockMovement.fromJson(Map<String, dynamic> json) => StockMovement(
        id: json['id'] as String,
        productId: json['productId'] as String,
        productName: json['productName'] as String,
        type: MovementType.values.byName(json['type'] as String),
        quantity: json['quantity'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String),
        note: json['note'] as String? ?? '',
      );
}
