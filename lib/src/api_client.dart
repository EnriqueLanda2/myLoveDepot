import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'models.dart';

class DepotApiClient {
  DepotApiClient({
    this.baseUrl = const String.fromEnvironment('API_BASE_URL'),
  });

  final String baseUrl;
  String token = '';

  bool get enabled => baseUrl.trim().isNotEmpty && token.isNotEmpty;
  Uri _uri(String path) =>
      Uri.parse('${baseUrl.replaceAll(RegExp(r'/$'), '')}$path');
  Map<String, String> get _headers => {
        'content-type': 'application/json',
        if (token.isNotEmpty) 'authorization': 'Bearer $token',
      };

  Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await http.post(
      _uri('/auth/login'),
      headers: const {'content-type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    _ensureSuccess(response);
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    token = data['token'] as String;
    return data;
  }

  Future<List<Product>> getProducts() async {
    final response = await http.get(_uri('/api/products'), headers: _headers);
    _ensureSuccess(response);
    return (jsonDecode(response.body) as List)
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<List<ProductCategory>> getCategories() async {
    final response = await http.get(_uri('/api/categories'), headers: _headers);
    _ensureSuccess(response);
    return (jsonDecode(response.body) as List)
        .map((item) => ProductCategory.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<ProductCategory> createCategory(String name) async {
    final response = await http.post(
      _uri('/api/categories'),
      headers: _headers,
      body: jsonEncode({'name': name}),
    );
    _ensureSuccess(response);
    return ProductCategory.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<ProductCategory> renameCategory(String id, String name) async {
    final response = await http.patch(
      _uri('/api/categories/$id'),
      headers: _headers,
      body: jsonEncode({'name': name}),
    );
    _ensureSuccess(response);
    return ProductCategory.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Future<void> deleteCategory(String id) async {
    final response =
        await http.delete(_uri('/api/categories/$id'), headers: _headers);
    _ensureSuccess(response);
  }

  /// Pide al servidor que reconstruya el modelo 3D con las fotos ya subidas.
  Future<String> buildProductModel(String productId) async {
    final response = await http.post(
      _uri('/api/products/$productId/model'),
      headers: _headers,
    );
    _ensureSuccess(response);
    return (jsonDecode(response.body) as Map<String, dynamic>)['modelUrl']
        as String;
  }

  Future<String> uploadProductImage(
      String productId, int viewIndex, Uint8List bytes) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/api/uploads/product-image'),
    )
      ..headers['authorization'] = 'Bearer $token'
      ..fields['productId'] = productId
      ..fields['viewIndex'] = '$viewIndex'
      ..files.add(http.MultipartFile.fromBytes('image', bytes,
          filename: '$productId-$viewIndex.jpg'));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    _ensureSuccess(response);
    return (jsonDecode(response.body) as Map<String, dynamic>)['url'] as String;
  }

  Future<void> saveProduct(Product product) async {
    final body = product.toJson()
      ..remove('photoBase64')
      ..remove('pendingImagesBase64')
      ..remove('modelUrl');
    final response = await http.post(
      _uri('/api/products'),
      headers: _headers,
      body: jsonEncode(body),
    );
    _ensureSuccess(response);
  }

  Future<void> deleteProduct(String id) async {
    final response =
        await http.delete(_uri('/api/products/$id'), headers: _headers);
    _ensureSuccess(response);
  }

  Future<void> moveStock({
    required Product product,
    required MovementType type,
    required int quantity,
    required String note,
  }) async {
    final response = await http.post(
      _uri('/api/products/${product.id}/movements'),
      headers: _headers,
      body: jsonEncode({
        'type': type.name,
        'quantity': quantity,
        'note': note,
      }),
    );
    _ensureSuccess(response);
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw DepotApiException(response.statusCode, response.body);
    }
  }
}

class DepotApiException implements Exception {
  DepotApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  /// El texto que la API manda en `error`, listo para enseñarlo al usuario.
  String get reason {
    try {
      final decoded = jsonDecode(message);
      if (decoded is Map && decoded['error'] is String) {
        return decoded['error'] as String;
      }
    } on FormatException {
      // La respuesta no era JSON; se usa el mensaje genérico.
    }
    return 'No se pudo completar la operación.';
  }

  @override
  String toString() => 'DepotApiException($statusCode): $message';
}
