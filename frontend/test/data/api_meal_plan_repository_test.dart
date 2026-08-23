import 'dart:convert';
import 'dart:io';

import 'package:cookbuk/data/api_meal_plan_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HttpServer server;
  late ApiMealPlanRepository repository;
  final requests = <_RequestLog>[];

  setUp(() async {
    requests.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    repository = ApiMealPlanRepository(
      baseUrl: 'http://${server.address.host}:${server.port}',
    );

    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      requests.add(
        _RequestLog(
          method: request.method,
          path: request.uri.path,
          query: request.uri.query,
          body: body,
          token: request.headers.value('x-cookbuk-token'),
        ),
      );

      request.response.headers.contentType = ContentType.json;
      if (request.method == 'GET' && request.uri.path == '/meal-plan') {
        request.response.write(
          jsonEncode([
            {
              'plannedFor': '2026-08-23',
              'meal': 'breakfast',
              'slotType': 'recipe',
              'recipeId': 'recipe-1',
            },
          ]),
        );
      } else if (request.method == 'POST' &&
          request.uri.path == '/meal-plan/close-day/2026-08-23') {
        request.response.write(
          jsonEncode({
            'plannedFor': '2026-08-23',
            'recordedCount': 2,
            'skippedCount': 1,
          }),
        );
      } else {
        request.response.write(jsonEncode({'ok': true}));
      }
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
  });

  test('reads meal plan slots from the backend', () async {
    final slots = await repository.getRange(
      from: DateTime(2026, 8, 23),
      to: DateTime(2026, 8, 24),
    );

    expect(slots, hasLength(1));
    expect(slots.single.meal, 'breakfast');
    expect(slots.single.recipeId, 'recipe-1');
    expect(requests.single.method, 'GET');
    expect(requests.single.path, '/meal-plan');
    expect(requests.single.query, 'from=2026-08-23&to=2026-08-24');
  });

  test('sends shared token headers when configured', () async {
    repository = ApiMealPlanRepository(
      baseUrl: 'http://${server.address.host}:${server.port}',
      sharedToken: 'secret',
    );

    await repository.getRange(
      from: DateTime(2026, 8, 23),
      to: DateTime(2026, 8, 24),
    );

    expect(requests.single.token, 'secret');
  });

  test('writes meal plan slot payloads', () async {
    final date = DateTime(2026, 8, 23);

    await repository.setRecipe(
      date: date,
      meal: 'breakfast',
      recipeId: 'recipe-1',
    );
    await repository.setLeftovers(date: date, meal: 'lunch');
    await repository.setEmpty(date: date, meal: 'dinner');

    expect(requests.map((request) => request.method), ['PUT', 'PUT', 'PUT']);
    expect(requests.map((request) => request.path), [
      '/meal-plan/2026-08-23/breakfast',
      '/meal-plan/2026-08-23/lunch',
      '/meal-plan/2026-08-23/dinner',
    ]);
    expect(jsonDecode(requests[0].body), {
      'slotType': 'recipe',
      'recipeId': 'recipe-1',
    });
    expect(jsonDecode(requests[1].body), {'slotType': 'leftovers'});
    expect(jsonDecode(requests[2].body), {'slotType': 'empty'});
  });

  test('closes a planned day', () async {
    final result = await repository.closeDay(DateTime(2026, 8, 23));

    expect(result.plannedFor, DateTime(2026, 8, 23));
    expect(result.recordedCount, 2);
    expect(result.skippedCount, 1);
    expect(requests.single.method, 'POST');
    expect(requests.single.path, '/meal-plan/close-day/2026-08-23');
  });
}

class _RequestLog {
  const _RequestLog({
    required this.method,
    required this.path,
    required this.query,
    required this.body,
    required this.token,
  });

  final String method;
  final String path;
  final String query;
  final String body;
  final String? token;
}
