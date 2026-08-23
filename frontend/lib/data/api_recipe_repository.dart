import 'dart:convert';

import 'package:cookbuk/data/recipe_repository.dart';
import 'package:cookbuk/domain/recipe.dart';
import 'package:http/http.dart' as http;

class ApiRecipeRepository implements RecipeRepository {
  ApiRecipeRepository({required String baseUrl})
    : _baseUri = Uri.parse(baseUrl.replaceFirst(RegExp(r'/$'), ''));

  final Uri _baseUri;

  @override
  Future<List<Recipe>> getAll() async {
    final response = await _send('GET', '/recipes');
    final decoded = jsonDecode(response);
    return (decoded as List<dynamic>)
        .map((item) => Recipe.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> add(Recipe recipe) async {
    await _send('POST', '/recipes', body: _recipePayload(recipe));
  }

  @override
  Future<void> deleteById(String id) async {
    await _send('DELETE', '/recipes/$id');
  }

  @override
  Future<void> update(Recipe recipe) async {
    await _send('PATCH', '/recipes/${recipe.id}', body: _recipePayload(recipe));
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

  Future<String> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final headers = body == null
        ? null
        : const {'Content-Type': 'application/json'};
    final encodedBody = body == null ? null : jsonEncode(body);
    final response = await switch (method) {
      'GET' => http.get(_uri(path)),
      'POST' => http.post(_uri(path), headers: headers, body: encodedBody),
      'PATCH' => http.patch(_uri(path), headers: headers, body: encodedBody),
      'DELETE' => http.delete(_uri(path)),
      _ => throw ApiRecipeRepositoryException('Unsupported method: $method'),
    };

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiRecipeRepositoryException(
        'Backend request failed: $method $path ${response.statusCode} ${response.body}',
      );
    }

    return response.body;
  }
}

class ApiRecipeRepositoryException implements Exception {
  const ApiRecipeRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
