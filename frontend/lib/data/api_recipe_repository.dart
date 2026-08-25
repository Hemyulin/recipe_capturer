import 'dart:async';
import 'dart:convert';

import 'package:cookbuk/data/demo_recipe_data.dart';
import 'package:cookbuk/data/recipe_repository.dart';
import 'package:cookbuk/domain/recipe.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiRecipeRepository
    implements
        RecipeRepository,
        RecipeImageRepository,
        RecipeAiImportRepository,
        RecipeAiPolishRepository,
        RecipeAiImageRepository {
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
      await _replaceCachedRecipes(recipes);
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
    final savedRecipe = _recipeFromJson(
      jsonDecode(response) as Map<String, dynamic>,
    );
    await _upsertCachedRecipe(savedRecipe);
    return savedRecipe;
  }

  @override
  Future<void> deleteById(String id) async {
    await _send('DELETE', '/recipes/$id', useSaveErrorMessage: true);
    await _removeCachedRecipe(id);
  }

  @override
  Future<Recipe> update(Recipe recipe) async {
    final response = await _send(
      'PATCH',
      '/recipes/${recipe.id}',
      body: _recipePayload(recipe),
      useSaveErrorMessage: true,
    );
    final updatedRecipe = _recipeFromJson(
      jsonDecode(response) as Map<String, dynamic>,
    );
    await _upsertCachedRecipe(updatedRecipe);
    return updatedRecipe;
  }

  @override
  Future<Recipe> uploadImage({
    required String recipeId,
    required String imagePath,
  }) async {
    final response = await _sendMultipart(
      'POST',
      '/recipes/$recipeId/image',
      [imagePath],
      timeout: _imageUploadTimeout,
      useSaveErrorMessage: true,
    );
    final updatedRecipe = _recipeFromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    await _upsertCachedRecipe(updatedRecipe);
    return updatedRecipe;
  }

  @override
  Future<Recipe> importFromImage({required String imagePath}) async {
    return importFromImages(imagePaths: [imagePath]);
  }

  @override
  Future<Recipe> importFromImages({required List<String> imagePaths}) async {
    final response = await _sendMultipart(
      'POST',
      '/recipes/imports/photo',
      imagePaths.take(_maxImportImages).toList(),
      timeout: _aiImportTimeout,
      useSaveErrorMessage: true,
    );
    return _recipeDraftFromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
      imagePaths: imagePaths.take(_maxImportImages).toList(),
    );
  }

  @override
  Future<Recipe> polishRecipe(Recipe recipe) async {
    final response = await _send(
      'POST',
      '/recipes/imports/polish',
      body: _recipePayload(recipe),
      timeout: _aiPolishTimeout,
      useSaveErrorMessage: true,
    );
    return _recipeDraftFromJson(
      jsonDecode(response) as Map<String, dynamic>,
      imagePaths: recipe.imagePaths,
    );
  }

  @override
  Future<String> generateRecipeImage(Recipe recipe) async {
    final response = await _send(
      'POST',
      '/recipes/imports/generated-image',
      body: _recipePayload(recipe),
      timeout: _aiImageTimeout,
      useSaveErrorMessage: true,
    );
    final decoded = jsonDecode(response) as Map<String, dynamic>;
    return _absoluteImagePath((decoded['imagePath'] as String? ?? '').trim());
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
      'preparationTasks': recipe.preparationTasks,
      'tags': recipe.tags,
      'imagePaths': recipe.imagePaths.map(_imagePathForPayload).toList(),
    };
  }

  Recipe _recipeFromJson(Map<String, dynamic> json) {
    final normalized = Map<String, dynamic>.from(json);
    normalized['imagePaths'] = (json['imagePaths'] as List<dynamic>? ?? [])
        .map((path) => _absoluteImagePath(path.toString()))
        .toList();
    return Recipe.fromJson(normalized);
  }

  Recipe _recipeDraftFromJson(
    Map<String, dynamic> json, {
    required List<String> imagePaths,
  }) {
    return Recipe.create(
      (json['title'] as String? ?? '').trim(),
      notes: (json['notes'] as String? ?? '').trim(),
      servings: json['servings'] as int?,
      season: (json['season'] as String? ?? '').trim(),
      prepTimeMinutes: json['prepTimeMinutes'] as int?,
      cookTimeMinutes: json['cookTimeMinutes'] as int?,
      imagePaths: imagePaths,
      ingredients: (json['ingredients'] as List<dynamic>? ?? [])
          .map(RecipeIngredient.fromJson)
          .toList(),
      instructions: (json['instructions'] as List<dynamic>? ?? [])
          .map((step) => step.toString())
          .toList(),
      preparationTasks: (json['preparationTasks'] as List<dynamic>? ?? [])
          .map((task) => task.toString())
          .toList(),
      tags: (json['tags'] as List<dynamic>? ?? [])
          .map((tag) => tag.toString())
          .followedBy(const ['needs_review'])
          .toSet()
          .toList(),
    );
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

  String _imagePathForPayload(String value) {
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasScheme) return trimmed;
    if (uri.host != _activeBaseUri.host ||
        uri.scheme != _activeBaseUri.scheme) {
      return trimmed;
    }
    if (_activeBaseUri.hasPort && uri.port != _activeBaseUri.port) {
      return trimmed;
    }
    if (!uri.path.startsWith('/images/')) return trimmed;
    return uri.path;
  }

  Future<String> _send(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Duration timeout = _requestTimeout,
    bool useSaveErrorMessage = false,
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
          timeout,
        );
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
    List<String> imagePaths, {
    required Duration timeout,
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
        for (final imagePath in imagePaths) {
          request.files.add(
            await http.MultipartFile.fromPath('image', imagePath),
          );
        }

        final streamedResponse = await request.send().timeout(timeout);
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw ApiRecipeRepositoryException(
            _statusMessage(response.statusCode, response.body),
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
    Duration timeout,
  ) async {
    final headers = {
      ..._authHeaders(),
      if (body != null) 'Content-Type': 'application/json',
    };
    final encodedBody = body == null ? null : jsonEncode(body);
    final response = await switch (method) {
      'GET' => http.get(_uri(baseUri, path), headers: headers).timeout(timeout),
      'POST' =>
        http
            .post(_uri(baseUri, path), headers: headers, body: encodedBody)
            .timeout(timeout),
      'PATCH' =>
        http
            .patch(_uri(baseUri, path), headers: headers, body: encodedBody)
            .timeout(timeout),
      'DELETE' =>
        http.delete(_uri(baseUri, path), headers: headers).timeout(timeout),
      _ => throw ApiRecipeRepositoryException('Unsupported method: $method'),
    };

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiRecipeRepositoryException(
        _statusMessage(response.statusCode, response.body),
      );
    }

    return response.body;
  }

  Map<String, String> _authHeaders() {
    if (_sharedToken.isEmpty) return const {};
    return {'x-cookbuk-token': _sharedToken};
  }

  Future<List<Recipe>> _offlineRecipeList() async {
    return _offlineRecipes ??=
        await _cachedRecipeList() ?? DemoRecipeData.recipes();
  }

  Future<void> _replaceCachedRecipes(List<Recipe> recipes) async {
    _offlineRecipes = recipes;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _recipeCacheStorageKey,
      jsonEncode(recipes.map((recipe) => recipe.toJson()).toList()),
    );
  }

  Future<void> _upsertCachedRecipe(Recipe recipe) async {
    final cachedRecipes = await _cachedRecipeList() ?? <Recipe>[];
    final index = cachedRecipes.indexWhere((cached) => cached.id == recipe.id);
    if (index == -1) {
      cachedRecipes.add(recipe);
    } else {
      cachedRecipes[index] = recipe;
    }
    await _replaceCachedRecipes(cachedRecipes);
  }

  Future<void> _removeCachedRecipe(String id) async {
    final cachedRecipes = await _cachedRecipeList() ?? <Recipe>[];
    cachedRecipes.removeWhere((recipe) => recipe.id == id);
    await _replaceCachedRecipes(cachedRecipes);
  }

  Future<List<Recipe>?> _cachedRecipeList() async {
    if (_offlineRecipes != null) return _offlineRecipes;

    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_recipeCacheStorageKey);
    if (encoded == null || encoded.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(encoded) as List<dynamic>;
      return decoded
          .map((item) => _recipeFromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      await preferences.remove(_recipeCacheStorageKey);
      return null;
    }
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

  String _statusMessage(int statusCode, String responseBody) {
    final backendMessage = _backendMessage(responseBody);
    if (backendMessage != null) return backendMessage;

    if (statusCode == 401 || statusCode == 403) {
      return 'Pi hat die Anfrage abgelehnt. Prüfe den CookBuk Token.';
    }
    if (statusCode == 503) {
      return 'KI-Import ist auf dem Pi noch nicht konfiguriert.';
    }
    if (statusCode >= 500) {
      return 'Pi Backend hat einen Serverfehler gemeldet.';
    }
    return 'Pi Backend konnte das Rezept nicht speichern. HTTP $statusCode.';
  }

  String? _backendMessage(String responseBody) {
    if (responseBody.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(responseBody);
      if (decoded is! Map<String, dynamic>) return null;
      final message = decoded['message'];
      final normalized = switch (message) {
        String value => value.trim(),
        List<dynamic> values =>
          values.map((value) => value.toString()).join('\n'),
        _ => '',
      };
      if (normalized.isEmpty) return null;

      if (normalized.startsWith('AI recipe import is not configured')) {
        return 'KI-Import ist auf dem Pi noch nicht konfiguriert. Prüfe OPENAI_API_KEY.';
      }
      if (normalized.startsWith('AI recipe import failed.')) {
        return 'KI-Import fehlgeschlagen. ${normalized.replaceFirst('AI recipe import failed. ', '')}';
      }
      if (normalized.startsWith('AI recipe import returned')) {
        return 'KI-Import hat keine lesbaren Rezeptdaten geliefert.';
      }
      if (normalized.startsWith('AI recipe polish is not configured')) {
        return 'KI-Aufräumen ist auf dem Pi noch nicht konfiguriert. Prüfe OPENAI_API_KEY.';
      }
      if (normalized.startsWith('AI recipe polish failed.')) {
        return 'KI-Aufräumen fehlgeschlagen. ${normalized.replaceFirst('AI recipe polish failed. ', '')}';
      }
      if (normalized.startsWith('AI recipe polish returned')) {
        return 'KI-Aufräumen hat keine lesbaren Rezeptdaten geliefert.';
      }
      if (normalized.startsWith('AI recipe image is not configured')) {
        return 'KI-Bild ist auf dem Pi noch nicht konfiguriert. Prüfe OPENAI_API_KEY.';
      }
      if (normalized.startsWith('AI recipe image failed.')) {
        return 'KI-Bild fehlgeschlagen. ${normalized.replaceFirst('AI recipe image failed. ', '')}';
      }
      if (normalized.startsWith('AI recipe image returned')) {
        return 'KI-Bild hat kein lesbares Bild geliefert.';
      }
      if (normalized.startsWith('Only image uploads')) {
        return 'Das Bildformat wurde vom Pi nicht akzeptiert.';
      }
      if (normalized.startsWith('Image file is empty')) {
        return 'Das Bild ist leer und konnte nicht hochgeladen werden.';
      }

      return normalized;
    } catch (_) {
      return null;
    }
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
  static const _imageUploadTimeout = Duration(seconds: 20);
  static const _aiImportTimeout = Duration(seconds: 120);
  static const _aiPolishTimeout = Duration(seconds: 90);
  static const _aiImageTimeout = Duration(seconds: 150);
  static const _maxImportImages = 5;
  static const _recipeCacheStorageKey = 'cookbuk.cachedRecipes.v1';
}

class ApiRecipeRepositoryException extends RecipeSaveException {
  const ApiRecipeRepositoryException(super.userMessage);
}
