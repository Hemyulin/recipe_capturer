import 'dart:async';
import 'dart:convert';

import 'package:cookbuk/data/meal_plan_repository.dart';
import 'package:cookbuk/domain/meal_plan_slot.dart';
import 'package:http/http.dart' as http;

class ApiMealPlanRepository implements MealPlanRepository {
  ApiMealPlanRepository({
    String? baseUrl,
    List<String>? baseUrls,
    String sharedToken = '',
  }) : _baseUris = _parseBaseUris(baseUrls ?? [baseUrl ?? '']),
       _sharedToken = sharedToken.trim();

  final List<Uri> _baseUris;
  final String _sharedToken;
  final Map<String, MealPlanSlot> _offlineSlots = {};
  late Uri _activeBaseUri = _baseUris.first;

  @override
  Future<List<MealPlanSlot>> getRange({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final response = await _send(
        'GET',
        '/meal-plan',
        queryParameters: {'from': _dateKey(from), 'to': _dateKey(to)},
      );
      final decoded = jsonDecode(response);
      return (decoded as List<dynamic>)
          .map((item) => MealPlanSlot.fromJson(item as Map<String, dynamic>))
          .toList();
    } on Object catch (error) {
      if (!_isOfflineError(error)) rethrow;
      return _offlineRange(from: from, to: to);
    }
  }

  @override
  Future<void> setRecipe({
    required DateTime date,
    required String meal,
    required String recipeId,
  }) async {
    await _upsert(
      date: date,
      meal: meal,
      body: {'slotType': 'recipe', 'recipeId': recipeId},
    );
  }

  @override
  Future<void> setLeftovers({
    required DateTime date,
    required String meal,
  }) async {
    await _upsert(date: date, meal: meal, body: {'slotType': 'leftovers'});
  }

  @override
  Future<void> setEmpty({required DateTime date, required String meal}) async {
    await _upsert(date: date, meal: meal, body: {'slotType': 'empty'});
  }

  @override
  Future<void> setExtras({
    required DateTime date,
    required String meal,
    required List<String> extras,
    List<String> recipeExtraIds = const [],
  }) async {
    final normalized = _normalizeExtras(extras);
    final normalizedRecipeExtraIds = _normalizeRecipeExtraIds(recipeExtraIds);
    await _send(
      'PUT',
      '/meal-plan/${_dateKey(date)}/$meal/extras',
      body: {'extras': normalized, 'recipeExtraIds': normalizedRecipeExtraIds},
    );
  }

  @override
  Future<CloseDayResult> closeDay(DateTime date) async {
    final response = await _send(
      'POST',
      '/meal-plan/close-day/${_dateKey(date)}',
    );
    return CloseDayResult.fromJson(
      jsonDecode(response) as Map<String, dynamic>,
    );
  }

  Future<void> _upsert({
    required DateTime date,
    required String meal,
    required Map<String, dynamic> body,
  }) async {
    await _send('PUT', '/meal-plan/${_dateKey(date)}/$meal', body: body);
  }

  Uri _uri(Uri baseUri, String path, {Map<String, String>? queryParameters}) {
    return baseUri.replace(
      path: '${baseUri.path}$path',
      queryParameters: queryParameters,
    );
  }

  Future<String> _send(
    String method,
    String path, {
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
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
          queryParameters: queryParameters,
          body: body,
        );
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
    String path, {
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
  }) async {
    final headers = {
      ..._authHeaders(),
      if (body != null) 'Content-Type': 'application/json',
    };
    final encodedBody = body == null ? null : jsonEncode(body);
    final uri = _uri(baseUri, path, queryParameters: queryParameters);
    final response = await switch (method) {
      'GET' => http.get(uri, headers: headers).timeout(_requestTimeout),
      'POST' =>
        http
            .post(uri, headers: headers, body: encodedBody)
            .timeout(_requestTimeout),
      'PUT' =>
        http
            .put(uri, headers: headers, body: encodedBody)
            .timeout(_requestTimeout),
      _ => throw ApiMealPlanRepositoryException('Unsupported method: $method'),
    };

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiMealPlanRepositoryException(
        'Backend request failed: $method $path ${response.statusCode} ${response.body}',
      );
    }

    return response.body;
  }

  Map<String, String> _authHeaders() {
    if (_sharedToken.isEmpty) return const {};
    return {'x-cookbuk-token': _sharedToken};
  }

  String _dateKey(DateTime date) {
    return [
      date.year.toString().padLeft(4, '0'),
      date.month.toString().padLeft(2, '0'),
      date.day.toString().padLeft(2, '0'),
    ].join('-');
  }

  List<MealPlanSlot> _offlineRange({
    required DateTime from,
    required DateTime to,
  }) {
    final fromKey = _dateKey(from);
    final toKey = _dateKey(to);
    return _offlineSlots.values.where((slot) {
      final key = _dateKey(slot.plannedFor);
      return key.compareTo(fromKey) >= 0 && key.compareTo(toKey) <= 0;
    }).toList();
  }

  List<String> _normalizeExtras(List<String> values) {
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .take(8)
        .toList();
  }

  List<String> _normalizeRecipeExtraIds(List<String> values) {
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .take(8)
        .toList();
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

class ApiMealPlanRepositoryException implements Exception {
  const ApiMealPlanRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
