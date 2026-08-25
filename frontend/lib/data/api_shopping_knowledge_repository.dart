import 'dart:async';
import 'dart:convert';

import 'package:cookbuk/data/recipe_repository.dart';
import 'package:cookbuk/data/shopping_knowledge_repository.dart';
import 'package:cookbuk/domain/shopping_knowledge.dart';
import 'package:http/http.dart' as http;

class ApiShoppingKnowledgeRepository implements ShoppingKnowledgeRepository {
  ApiShoppingKnowledgeRepository({
    String? baseUrl,
    List<String>? baseUrls,
    String sharedToken = '',
  }) : _baseUris = _parseBaseUris(baseUrls ?? [baseUrl ?? '']),
       _sharedToken = sharedToken.trim();

  final List<Uri> _baseUris;
  final String _sharedToken;
  late Uri _activeBaseUri = _baseUris.first;

  @override
  Future<List<ShoppingStore>> getStores() async {
    final response = await _send('GET', '/shopping/stores');
    return (jsonDecode(response) as List<dynamic>)
        .map((item) => ShoppingStore.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ShoppingStore> addStore(String name) async {
    final response = await _send(
      'POST',
      '/shopping/stores',
      body: {'name': name},
    );
    return ShoppingStore.fromJson(jsonDecode(response) as Map<String, dynamic>);
  }

  @override
  Future<ShoppingStore> updateStore({
    required String id,
    String? name,
    bool? isActive,
  }) async {
    final response = await _send(
      'PATCH',
      '/shopping/stores/$id',
      body: {
        if (name != null) 'name': name,
        if (isActive != null) 'isActive': isActive,
      },
    );
    return ShoppingStore.fromJson(jsonDecode(response) as Map<String, dynamic>);
  }

  @override
  Future<void> deleteStore(String id) async {
    await _send('DELETE', '/shopping/stores/$id');
  }

  @override
  Future<List<ShoppingKnowledgeItem>> getItems() async {
    final response = await _send('GET', '/shopping/items');
    return (jsonDecode(response) as List<dynamic>)
        .map(
          (item) =>
              ShoppingKnowledgeItem.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  @override
  Future<ShoppingKnowledgeItem> addItem({
    required String name,
    String? storeId,
  }) async {
    final response = await _send(
      'POST',
      '/shopping/items',
      body: {'name': name, 'storeId': storeId},
    );
    return ShoppingKnowledgeItem.fromJson(
      jsonDecode(response) as Map<String, dynamic>,
    );
  }

  @override
  Future<ShoppingKnowledgeItem> updateItem({
    required String id,
    String? name,
    String? storeId,
  }) async {
    final response = await _send(
      'PATCH',
      '/shopping/items/$id',
      body: {if (name != null) 'name': name, 'storeId': storeId},
    );
    return ShoppingKnowledgeItem.fromJson(
      jsonDecode(response) as Map<String, dynamic>,
    );
  }

  @override
  Future<void> deleteItem(String id) async {
    await _send('DELETE', '/shopping/items/$id');
  }

  @override
  Future<List<ManualShoppingItem>> getManualItems({
    required DateTime weekStart,
  }) async {
    final response = await _send(
      'GET',
      '/shopping/manual-items',
      queryParameters: {'weekStart': _dateKey(weekStart)},
    );
    return _manualItemsFromJson(response);
  }

  @override
  Future<List<ManualShoppingItem>> addManualItem({
    required DateTime weekStart,
    required String name,
    String quantityLabel = '',
    String? storeId,
    bool rememberStore = false,
  }) async {
    final response = await _send(
      'POST',
      '/shopping/manual-items/${_dateKey(weekStart)}',
      body: {
        'name': name,
        'quantityLabel': quantityLabel,
        'storeId': storeId,
        'rememberStore': rememberStore,
      },
    );
    return _manualItemsFromJson(response);
  }

  @override
  Future<List<ManualShoppingItem>> updateManualItem({
    required String id,
    String? name,
    String? quantityLabel,
    String? storeId,
    bool rememberStore = false,
  }) async {
    final response = await _send(
      'PATCH',
      '/shopping/manual-items/$id',
      body: {
        if (name != null) 'name': name,
        if (quantityLabel != null) 'quantityLabel': quantityLabel,
        'storeId': storeId,
        'rememberStore': rememberStore,
      },
    );
    return _manualItemsFromJson(response);
  }

  @override
  Future<void> deleteManualItem(String id) async {
    await _send('DELETE', '/shopping/manual-items/$id');
  }

  List<ManualShoppingItem> _manualItemsFromJson(String response) {
    return (jsonDecode(response) as List<dynamic>)
        .map(
          (item) => ManualShoppingItem.fromJson(item as Map<String, dynamic>),
        )
        .toList();
  }

  Future<String> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
    Duration timeout = const Duration(seconds: 2),
  }) async {
    Object? lastOfflineError;
    final orderedBaseUris = [
      _activeBaseUri,
      ..._baseUris.where((uri) => uri != _activeBaseUri),
    ];

    for (final baseUri in orderedBaseUris) {
      try {
        final response = await _sendToBaseUri(
          method,
          baseUri,
          path,
          body,
          queryParameters,
          timeout,
        );
        _activeBaseUri = baseUri;
        return response;
      } on Object catch (error) {
        if (!_isOfflineError(error)) rethrow;
        lastOfflineError = error;
      }
    }

    throw ApiShoppingKnowledgeRepositoryException(
      _offlineMessage(lastOfflineError),
    );
  }

  Future<String> _sendToBaseUri(
    String method,
    Uri baseUri,
    String path,
    Map<String, dynamic>? body,
    Map<String, String>? queryParameters,
    Duration timeout,
  ) async {
    final uri = _uri(baseUri, path, queryParameters);
    final headers = {
      ..._authHeaders(),
      if (body != null) 'Content-Type': 'application/json',
    };
    final encodedBody = body == null ? null : jsonEncode(body);
    final response = await switch (method) {
      'GET' => http.get(uri, headers: headers).timeout(timeout),
      'POST' =>
        http.post(uri, headers: headers, body: encodedBody).timeout(timeout),
      'PATCH' =>
        http.patch(uri, headers: headers, body: encodedBody).timeout(timeout),
      'DELETE' => http.delete(uri, headers: headers).timeout(timeout),
      _ => throw ApiShoppingKnowledgeRepositoryException(
        'Unsupported method: $method',
      ),
    };

    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 404) {
        throw const ApiShoppingKnowledgeUnavailableException();
      }
      throw ApiShoppingKnowledgeRepositoryException(
        'Backendfehler ${response.statusCode}',
      );
    }

    return response.body;
  }

  Uri _uri(Uri baseUri, String path, Map<String, String>? queryParameters) {
    return baseUri.replace(
      path: '${baseUri.path}$path',
      queryParameters: queryParameters,
    );
  }

  Map<String, String> _authHeaders() {
    if (_sharedToken.isEmpty) return const {};
    return {'x-cookbuk-token': _sharedToken};
  }

  String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}

List<Uri> _parseBaseUris(List<String> values) {
  final uris = values
      .map((value) => Uri.tryParse(value.trim()))
      .whereType<Uri>()
      .where((uri) => uri.hasScheme && uri.host.isNotEmpty)
      .toList();
  if (uris.isEmpty) return [Uri.parse('http://127.0.0.1:3000')];
  return uris;
}

bool _isOfflineError(Object error) {
  return error is TimeoutException ||
      error is http.ClientException ||
      error is ApiShoppingKnowledgeRepositoryException;
}

String _offlineMessage(Object? error) {
  if (error is ApiShoppingKnowledgeRepositoryException) {
    return error.userMessage;
  }
  return 'Pi antwortet nicht rechtzeitig. Prüfe WLAN, Tailscale oder die Backend-Adresse.';
}

class ApiShoppingKnowledgeRepositoryException extends RecipeSaveException {
  const ApiShoppingKnowledgeRepositoryException(super.userMessage);
}

class ApiShoppingKnowledgeUnavailableException implements Exception {
  const ApiShoppingKnowledgeUnavailableException();
}
