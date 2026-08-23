import 'dart:convert';

import 'package:cookbuk/data/recipe_repository.dart';
import 'package:cookbuk/domain/recipe.dart';
import 'package:http/http.dart' as http;

class ApiRecipeRepository implements RecipeRepository, RecipeImageRepository {
  ApiRecipeRepository({required String baseUrl, String sharedToken = ''})
    : _baseUri = Uri.parse(baseUrl.replaceFirst(RegExp(r'/$'), '')),
      _sharedToken = sharedToken.trim();

  final Uri _baseUri;
  final String _sharedToken;

  @override
  Future<List<Recipe>> getAll() async {
    final response = await _send('GET', '/recipes');
    final decoded = jsonDecode(response);
    return (decoded as List<dynamic>)
        .map((item) => _recipeFromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Recipe> add(Recipe recipe) async {
    final response = await _send(
      'POST',
      '/recipes',
      body: _recipePayload(recipe),
    );
    return _recipeFromJson(jsonDecode(response) as Map<String, dynamic>);
  }

  @override
  Future<void> deleteById(String id) async {
    await _send('DELETE', '/recipes/$id');
  }

  @override
  Future<Recipe> update(Recipe recipe) async {
    final response = await _send(
      'PATCH',
      '/recipes/${recipe.id}',
      body: _recipePayload(recipe),
    );
    return _recipeFromJson(jsonDecode(response) as Map<String, dynamic>);
  }

  @override
  Future<Recipe> uploadImage({
    required String recipeId,
    required String imagePath,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      _uri('/recipes/$recipeId/image'),
    );
    request.headers.addAll(_authHeaders());
    request.files.add(await http.MultipartFile.fromPath('image', imagePath));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiRecipeRepositoryException(
        'Backend request failed: POST /recipes/$recipeId/image ${response.statusCode} ${response.body}',
      );
    }

    return _recipeFromJson(jsonDecode(response.body) as Map<String, dynamic>);
  }

  Uri _uri(String path) {
    return _baseUri.replace(path: '${_baseUri.path}$path');
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
        scheme: _baseUri.scheme,
        userInfo: _baseUri.userInfo,
        host: _baseUri.host,
        port: _baseUri.hasPort ? _baseUri.port : null,
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
    final headers = {
      ..._authHeaders(),
      if (body != null) 'Content-Type': 'application/json',
    };
    final encodedBody = body == null ? null : jsonEncode(body);
    final response = await switch (method) {
      'GET' => http.get(_uri(path), headers: headers),
      'POST' => http.post(_uri(path), headers: headers, body: encodedBody),
      'PATCH' => http.patch(_uri(path), headers: headers, body: encodedBody),
      'DELETE' => http.delete(_uri(path), headers: headers),
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
}

class ApiRecipeRepositoryException implements Exception {
  const ApiRecipeRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
