import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'models.dart';

class DepotApiClient {
  DepotApiClient({
    this.baseUrl = const String.fromEnvironment('API_BASE_URL'),
    this.apiKey = const String.fromEnvironment('INVENTORY_API_KEY'),
  });

  final String baseUrl;
  final String apiKey;

  bool get enabled => baseUrl.trim().isNotEmpty && apiKey.trim().isNotEmpty;
  Uri _uri(String path) =>
      Uri.parse('${baseUrl.replaceAll(RegExp(r'/$'), '')}$path');
  Map<String, String> get _headers => {
        'content-type': 'application/json',
        'x-api-key': apiKey,
      };

  Future<List<Product>> getProducts() async {
    final response = await http.get(_uri('/api/products'), headers: _headers);
    _ensureSuccess(response);
    return (jsonDecode(response.body) as List)
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<String> uploadProductImage(String productId, Uint8List bytes) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/api/uploads/product-image'),
    )
      ..headers['x-api-key'] = apiKey
      ..fields['productId'] = productId
      ..files.add(http.MultipartFile.fromBytes('image', bytes,
          filename: '$productId.jpg'));
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    _ensureSuccess(response);
    return (jsonDecode(response.body) as Map<String, dynamic>)['url'] as String;
  }

  Future<void> saveProduct(Product product) async {
    final body = product.toJson()..remove('photoBase64');
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

  @override
  String toString() => 'DepotApiException($statusCode): $message';
}
