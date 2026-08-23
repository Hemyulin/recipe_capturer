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
    try {
      final response = await _send(
        'POST',
        '/recipes',
        body: _recipePayload(recipe),
      );
      return _recipeFromJson(jsonDecode(response) as Map<String, dynamic>);
    } on Object catch (error) {
      if (!_isOfflineError(error)) rethrow;
      _offlineRecipeList().insert(0, recipe);
      return recipe;
    }
  }

  @override
  Future<void> deleteById(String id) async {
    try {
      await _send('DELETE', '/recipes/$id');
    } on Object catch (error) {
      if (!_isOfflineError(error)) rethrow;
      _offlineRecipeList().removeWhere((recipe) => recipe.id == id);
    }
  }

  @override
  Future<Recipe> update(Recipe recipe) async {
    try {
      final response = await _send(
        'PATCH',
        '/recipes/${recipe.id}',
        body: _recipePayload(recipe),
      );
      return _recipeFromJson(jsonDecode(response) as Map<String, dynamic>);
    } on Object catch (error) {
      if (!_isOfflineError(error)) rethrow;
      final recipes = _offlineRecipeList();
      final index = recipes.indexWhere((item) => item.id == recipe.id);
      if (index == -1) {
        recipes.insert(0, recipe);
      } else {
        recipes[index] = recipe;
      }
      return recipe;
    }
  }

  @override
  Future<Recipe> uploadImage({
    required String recipeId,
    required String imagePath,
  }) async {
    try {
      final response = await _sendMultipart(
        'POST',
        '/recipes/$recipeId/image',
        imagePath,
      );
      return _recipeFromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } on Object catch (error) {
      if (!_isOfflineError(error)) rethrow;
      final recipes = _offlineRecipeList();
      final index = recipes.indexWhere((recipe) => recipe.id == recipeId);
      if (index == -1) {
        throw ApiRecipeRepositoryException(
          'Offline recipe not found: $recipeId',
        );
      }

      final updatedRecipe = recipes[index].copyWith(
        imagePaths: [imagePath, ...recipes[index].imagePaths.skip(1)],
      );
      recipes[index] = updatedRecipe;
      return updatedRecipe;
    }
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

    throw lastOfflineError ?? TimeoutException('Backend unavailable');
  }

  Future<http.Response> _sendMultipart(
    String method,
    String path,
    String imagePath,
  ) async {
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
            'Backend request failed: $method $path ${response.statusCode} ${response.body}',
          );
        }

        _activeBaseUri = baseUri;
        return response;
      } on Object catch (error) {
        if (!_isOfflineError(error)) rethrow;
        lastOfflineError = error;
      }
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
      throw ApiRecipeRepositoryException(
        'Backend request failed: $method $path ${response.statusCode} ${response.body}',
      );
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

class ApiRecipeRepositoryException implements Exception {
  const ApiRecipeRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
