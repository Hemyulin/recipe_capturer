import 'dart:async';
import 'dart:convert';

import 'package:cookbuk/data/demo_recipe_data.dart';
import 'package:cookbuk/data/recipe_repository.dart';
import 'package:cookbuk/domain/recipe.dart';
import 'package:http/http.dart' as http;

class ApiRecipeRepository implements RecipeRepository, RecipeImageRepository {
  ApiRecipeRepository({
    String? baseUrl,
    List<String>? baseUrls,
    String sharedToken = '',
  }) : _baseUris = _parseBaseUris(baseUrls ?? [baseUrl ?? '']),
       _sharedToken = sharedToken.trim();

  final List<Uri> _baseUris;
  final String _sharedToken;
  List<Recipe>? _offlineRecipes;
  late Uri _activeBaseUri = _baseUris.first;

  @override
  Future<List<Recipe>> getAll() async {
    try {
      final response = await _send('GET', '/recipes');
      final decoded = jsonDecode(response);
      final recipes = (decoded as List<dynamic>)
          .map((item) => _recipeFromJson(item as Map<String, dynamic>))
          .toList();
      _offlineRecipes = recipes;
      return recipes;
    } on Object catch (error) {
      if (!_isOfflineError(error)) rethrow;
      return _offlineRecipeList();
    }
  }

  @override
  Future<Recipe> add(Recipe recipe) async {
    final response = await _send(
      'POST',
      '/recipes',
      body: _recipePayload(recipe),
      useSaveErrorMessage: true,
    );
    return _recipeFromJson(jsonDecode(response) as Map<String, dynamic>);
  }

  @override
  Future<void> deleteById(String id) async {
    await _send('DELETE', '/recipes/$id', useSaveErrorMessage: true);
  }

  @override
  Future<Recipe> update(Recipe recipe) async {
    final response = await _send(
      'PATCH',
      '/recipes/${recipe.id}',
      body: _recipePayload(recipe),
      useSaveErrorMessage: true,
    );
    return _recipeFromJson(jsonDecode(response) as Map<String, dynamic>);
  }

  @override
  Future<Recipe> uploadImage({
    required String recipeId,
    required String imagePath,
  }) async {
    final response = await _sendMultipart(
      'POST',
      '/recipes/$recipeId/image',
      imagePath,
      useSaveErrorMessage: true,
    );
    return _recipeFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Uri _uri(Uri baseUri, String path) {
    return baseUri.replace(path: '${baseUri.path}$path');
  }

  Map<String, dynamic> _recipePayload(Recipe recipe) {
    return {
      'title': recipe.title,
      'notes': recipe.notes,
      'isFavorite': recipe.isFavorite,
      'servings': recipe.servings,
      'season': recipe.season,
      'prepTimeMinutes': recipe.prepTimeMinutes,
      'cookTimeMinutes': recipe.cookTimeMinutes,
      'ingredients': recipe.ingredients
          .map((ingredient) => ingredient.toJson())
          .toList(),
      'instructions': recipe.instructions,
      'tags': recipe.tags,
      'imagePaths': recipe.imagePaths,
    };
  }

  Recipe _recipeFromJson(Map<String, dynamic> json) {
    final normalized = Map<String, dynamic>.from(json);
    normalized['imagePaths'] = (json['imagePaths'] as List<dynamic>? ?? [])
        .map((path) => _absoluteImagePath(path.toString()))
        .toList();
    return Recipe.fromJson(normalized);
  }

  String _absoluteImagePath(String value) {
    if (value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('assets/')) {
      return value;
    }

    if (value.startsWith('/')) {
      return Uri(
        scheme: _activeBaseUri.scheme,
        userInfo: _activeBaseUri.userInfo,
        host: _activeBaseUri.host,
        port: _activeBaseUri.hasPort ? _activeBaseUri.port : null,
        path: value,
      ).toString();
    }

    return value;
  }

  Future<String> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool useSaveErrorMessage = false,
  }) async {
    Object? lastOfflineError;
    final orderedBaseUris = [
      _activeBaseUri,
      ..._baseUris.where((uri) => uri != _activeBaseUri),
    ];

    for (final baseUri in orderedBaseUris) {
      try {
        final response = await _sendToBaseUri(method, baseUri, path, body);
        _activeBaseUri = baseUri;
        return response;
      } on Object catch (error) {
        if (!_isOfflineError(error)) rethrow;
        lastOfflineError = error;
      }
    }

    if (useSaveErrorMessage) {
      throw ApiRecipeRepositoryException(_offlineMessage(lastOfflineError));
    }
    throw lastOfflineError ?? TimeoutException('Backend unavailable');
  }

  Future<http.Response> _sendMultipart(
    String method,
    String path,
    String imagePath, {
    bool useSaveErrorMessage = false,
  }) async {
    Object? lastOfflineError;
    final orderedBaseUris = [
      _activeBaseUri,
      ..._baseUris.where((uri) => uri != _activeBaseUri),
    ];

    for (final baseUri in orderedBaseUris) {
      try {
        final request = http.MultipartRequest(method, _uri(baseUri, path));
        request.headers.addAll(_authHeaders());
        request.files.add(
          await http.MultipartFile.fromPath('image', imagePath),
        );

        final streamedResponse = await request.send().timeout(_requestTimeout);
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw ApiRecipeRepositoryException(
            _statusMessage(response.statusCode),
          );
        }

        _activeBaseUri = baseUri;
        return response;
      } on Object catch (error) {
        if (!_isOfflineError(error)) rethrow;
        lastOfflineError = error;
      }
    }

    if (useSaveErrorMessage) {
      throw ApiRecipeRepositoryException(_offlineMessage(lastOfflineError));
    }
    throw lastOfflineError ?? TimeoutException('Backend unavailable');
  }

  Future<String> _sendToBaseUri(
    String method,
    Uri baseUri,
    String path,
    Map<String, dynamic>? body,
  ) async {
    final headers = {
      ..._authHeaders(),
      if (body != null) 'Content-Type': 'application/json',
    };
    final encodedBody = body == null ? null : jsonEncode(body);
    final response = await switch (method) {
      'GET' =>
        http
            .get(_uri(baseUri, path), headers: headers)
            .timeout(_requestTimeout),
      'POST' =>
        http
            .post(_uri(baseUri, path), headers: headers, body: encodedBody)
            .timeout(_requestTimeout),
      'PATCH' =>
        http
            .patch(_uri(baseUri, path), headers: headers, body: encodedBody)
            .timeout(_requestTimeout),
      'DELETE' =>
        http
            .delete(_uri(baseUri, path), headers: headers)
            .timeout(_requestTimeout),
      _ => throw ApiRecipeRepositoryException('Unsupported method: $method'),
    };

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiRecipeRepositoryException(_statusMessage(response.statusCode));
    }

    return response.body;
  }

  Map<String, String> _authHeaders() {
    if (_sharedToken.isEmpty) return const {};
    return {'x-cookbuk-token': _sharedToken};
  }

  List<Recipe> _offlineRecipeList() {
    return _offlineRecipes ??= DemoRecipeData.recipes();
  }

  bool _isOfflineError(Object error) {
    return error is TimeoutException || error is http.ClientException;
  }

  String _offlineMessage(Object? error) {
    if (error is TimeoutException) {
      return 'Pi antwortet nicht rechtzeitig. Prüfe WLAN, Tailscale oder die Backend-Adresse.';
    }
    return 'Pi nicht erreichbar. Prüfe WLAN, Tailscale oder die Backend-Adresse.';
  }

  String _statusMessage(int statusCode) {
    if (statusCode == 401 || statusCode == 403) {
      return 'Pi hat die Anfrage abgelehnt. Prüfe den CookBuk Token.';
    }
    if (statusCode >= 500) {
      return 'Pi Backend hat einen Serverfehler gemeldet.';
    }
    return 'Pi Backend konnte das Rezept nicht speichern. HTTP $statusCode.';
  }

  static List<Uri> _parseBaseUris(List<String> values) {
    final uris = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .map((value) => Uri.parse(value.replaceFirst(RegExp(r'/$'), '')))
        .toList();
    if (uris.isNotEmpty) return uris;
    return [Uri.parse('http://127.0.0.1:3000')];
  }

  static const _requestTimeout = Duration(seconds: 2);
}

class ApiRecipeRepositoryException extends RecipeSaveException {
  const ApiRecipeRepositoryException(super.userMessage);
}
