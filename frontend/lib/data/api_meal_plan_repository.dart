import 'dart:convert';

import 'package:cookbuk/data/meal_plan_repository.dart';
import 'package:cookbuk/domain/meal_plan_slot.dart';
import 'package:http/http.dart' as http;

class ApiMealPlanRepository implements MealPlanRepository {
  ApiMealPlanRepository({required String baseUrl, String sharedToken = ''})
    : _baseUri = Uri.parse(baseUrl.replaceFirst(RegExp(r'/$'), '')),
      _sharedToken = sharedToken.trim();

  final Uri _baseUri;
  final String _sharedToken;

  @override
  Future<List<MealPlanSlot>> getRange({
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _send(
      'GET',
      '/meal-plan',
      queryParameters: {'from': _dateKey(from), 'to': _dateKey(to)},
    );
    final decoded = jsonDecode(response);
    return (decoded as List<dynamic>)
        .map((item) => MealPlanSlot.fromJson(item as Map<String, dynamic>))
        .toList();
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
  Future<void> setLeftovers({required DateTime date, required String meal}) {
    return _upsert(date: date, meal: meal, body: {'slotType': 'leftovers'});
  }

  @override
  Future<void> setEmpty({required DateTime date, required String meal}) {
    return _upsert(date: date, meal: meal, body: {'slotType': 'empty'});
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

  Uri _uri(String path, {Map<String, String>? queryParameters}) {
    return _baseUri.replace(
      path: '${_baseUri.path}$path',
      queryParameters: queryParameters,
    );
  }

  Future<String> _send(
    String method,
    String path, {
    Map<String, String>? queryParameters,
    Map<String, dynamic>? body,
  }) async {
    final headers = {
      ..._authHeaders(),
      if (body != null) 'Content-Type': 'application/json',
    };
    final encodedBody = body == null ? null : jsonEncode(body);
    final uri = _uri(path, queryParameters: queryParameters);
    final response = await switch (method) {
      'GET' => http.get(uri, headers: headers),
      'POST' => http.post(uri, headers: headers, body: encodedBody),
      'PUT' => http.put(uri, headers: headers, body: encodedBody),
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
}

class ApiMealPlanRepositoryException implements Exception {
  const ApiMealPlanRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
