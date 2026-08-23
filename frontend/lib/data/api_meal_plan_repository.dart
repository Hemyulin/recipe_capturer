import 'dart:async';
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
  final Map<String, MealPlanSlot> _offlineSlots = {};

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
    try {
      await _upsert(
        date: date,
        meal: meal,
        body: {'slotType': 'recipe', 'recipeId': recipeId},
      );
    } on Object catch (error) {
      if (!_isOfflineError(error)) rethrow;
      _writeOfflineSlot(
        date: date,
        meal: meal,
        slotType: 'recipe',
        recipeId: recipeId,
      );
    }
  }

  @override
  Future<void> setLeftovers({
    required DateTime date,
    required String meal,
  }) async {
    try {
      await _upsert(date: date, meal: meal, body: {'slotType': 'leftovers'});
    } on Object catch (error) {
      if (!_isOfflineError(error)) rethrow;
      _writeOfflineSlot(date: date, meal: meal, slotType: 'leftovers');
    }
  }

  @override
  Future<void> setEmpty({required DateTime date, required String meal}) async {
    try {
      await _upsert(date: date, meal: meal, body: {'slotType': 'empty'});
    } on Object catch (error) {
      if (!_isOfflineError(error)) rethrow;
      _writeOfflineSlot(date: date, meal: meal, slotType: 'empty');
    }
  }

  @override
  Future<CloseDayResult> closeDay(DateTime date) async {
    try {
      final response = await _send(
        'POST',
        '/meal-plan/close-day/${_dateKey(date)}',
      );
      return CloseDayResult.fromJson(
        jsonDecode(response) as Map<String, dynamic>,
      );
    } on Object catch (error) {
      if (!_isOfflineError(error)) rethrow;
      final recordedCount = _offlineSlots.values
          .where(
            (slot) =>
                _dateKey(slot.plannedFor) == _dateKey(date) && slot.isRecipe,
          )
          .length;
      return CloseDayResult(
        plannedFor: _dateOnly(date),
        recordedCount: recordedCount,
        skippedCount: 0,
      );
    }
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
    if (_offlineSlots.isEmpty) _seedOfflineSlots();

    final fromKey = _dateKey(from);
    final toKey = _dateKey(to);
    return _offlineSlots.values.where((slot) {
      final key = _dateKey(slot.plannedFor);
      return key.compareTo(fromKey) >= 0 && key.compareTo(toKey) <= 0;
    }).toList();
  }

  void _seedOfflineSlots() {
    final today = _dateOnly(DateTime.now());
    _writeOfflineSlot(
      date: today,
      meal: 'breakfast',
      slotType: 'recipe',
      recipeId: 'demo-oatmeal',
    );
    _writeOfflineSlot(
      date: today,
      meal: 'lunch',
      slotType: 'recipe',
      recipeId: 'demo-chickpea-bowl',
    );
    _writeOfflineSlot(
      date: today,
      meal: 'dinner',
      slotType: 'recipe',
      recipeId: 'demo-chicken-curry',
    );
    _writeOfflineSlot(
      date: today.add(const Duration(days: 1)),
      meal: 'dinner',
      slotType: 'leftovers',
    );
    _writeOfflineSlot(
      date: today.add(const Duration(days: 2)),
      meal: 'breakfast',
      slotType: 'recipe',
      recipeId: 'demo-oatmeal-buns',
    );
    _writeOfflineSlot(
      date: today.add(const Duration(days: 2)),
      meal: 'dinner',
      slotType: 'recipe',
      recipeId: 'demo-tomato-lentil-soup',
    );
  }

  void _writeOfflineSlot({
    required DateTime date,
    required String meal,
    required String slotType,
    String? recipeId,
  }) {
    _offlineSlots['${_dateKey(date)}:$meal'] = MealPlanSlot(
      plannedFor: _dateOnly(date),
      meal: meal,
      slotType: slotType,
      recipeId: recipeId,
    );
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _isOfflineError(Object error) {
    return error is TimeoutException || error is http.ClientException;
  }

  static const _requestTimeout = Duration(seconds: 2);
}

class ApiMealPlanRepositoryException implements Exception {
  const ApiMealPlanRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}
