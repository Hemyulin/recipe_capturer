import 'dart:convert';
import 'dart:io';

import 'package:cookbuk/data/api_meal_plan_repository.dart';
import 'package:cookbuk/data/meal_plan_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late HttpServer server;
  late ApiMealPlanRepository repository;
  final requests = <_RequestLog>[];

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
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
              'extras': ['Brot'],
              'recipeExtraIds': ['recipe-side'],
            },
          ]),
        );
      } else if (request.method == 'GET' && request.uri.path == '/health') {
        request.response.write(jsonEncode({'ok': true}));
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
    expect(slots.single.extras, ['Brot']);
    expect(slots.single.recipeExtraIds, ['recipe-side']);
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

  test('tries the next backend URL when the first is unavailable', () async {
    final unavailableServer = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final unavailablePort = unavailableServer.port;
    await unavailableServer.close(force: true);
    repository = ApiMealPlanRepository(
      baseUrls: [
        'http://127.0.0.1:$unavailablePort',
        'http://${server.address.host}:${server.port}',
      ],
    );

    final slots = await repository.getRange(
      from: DateTime(2026, 8, 23),
      to: DateTime(2026, 8, 24),
    );

    expect(slots, hasLength(1));
    expect(requests.single.path, '/meal-plan');
  });

  test('writes meal plan slot payloads', () async {
    final date = DateTime(2026, 8, 23);

    await repository.setRecipe(
      date: date,
      meal: 'breakfast',
      recipeId: 'recipe-1',
    );
    await repository.setLeftovers(date: date, meal: 'lunch');
    await repository.setAway(
      date: date,
      meal: 'dinner',
      reason: 'Nicht zuhause',
    );
    await repository.setEmpty(date: date, meal: 'dinner');
    await repository.setExtras(
      date: date,
      meal: 'dinner',
      extras: ['Brot', 'Butter'],
      recipeExtraIds: ['recipe-side'],
    );

    expect(requests.map((request) => request.method), [
      'PUT',
      'PUT',
      'PUT',
      'PUT',
      'PUT',
    ]);
    expect(requests.map((request) => request.path), [
      '/meal-plan/2026-08-23/breakfast',
      '/meal-plan/2026-08-23/lunch',
      '/meal-plan/2026-08-23/dinner',
      '/meal-plan/2026-08-23/dinner',
      '/meal-plan/2026-08-23/dinner/extras',
    ]);
    expect(jsonDecode(requests[0].body), {
      'slotType': 'recipe',
      'recipeId': 'recipe-1',
    });
    expect(jsonDecode(requests[1].body), {'slotType': 'leftovers'});
    expect(jsonDecode(requests[2].body), {
      'slotType': 'away',
      'extras': ['Nicht zuhause'],
    });
    expect(jsonDecode(requests[3].body), {'slotType': 'empty'});
    expect(jsonDecode(requests[4].body), {
      'extras': ['Brot', 'Butter'],
      'recipeExtraIds': ['recipe-side'],
    });
  });

  test('tests backend connection', () async {
    final result = await repository.testConnection();

    expect(result.isConnected, true);
    expect(result.activeBaseUrl, startsWith('http://127.0.0.1:'));
    expect(repository.lastSuccessfulConnectionAt, isNotNull);
    expect(requests.single.method, 'GET');
    expect(requests.single.path, '/health');
  });

  test('queues writes when backend is unavailable', () async {
    final unavailableServer = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final port = unavailableServer.port;
    await unavailableServer.close(force: true);
    repository = ApiMealPlanRepository(baseUrl: 'http://127.0.0.1:$port');

    await expectLater(
      repository.setRecipe(
        date: DateTime(2026, 8, 23),
        meal: 'breakfast',
        recipeId: 'recipe-1',
      ),
      throwsA(isA<MealPlanQueuedException>()),
    );

    final slots = await repository.getRange(
      from: DateTime(2026, 8, 23),
      to: DateTime(2026, 8, 23),
    );
    expect(slots.single.meal, 'breakfast');
    expect(slots.single.recipeId, 'recipe-1');
    expect(repository.syncStatus.phase, MealPlanSyncPhase.queued);
    expect(repository.syncStatus.pendingCount, 1);
  });

  test('syncs queued writes when backend becomes available', () async {
    final unavailableServer = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final port = unavailableServer.port;
    await unavailableServer.close(force: true);
    repository = ApiMealPlanRepository(baseUrl: 'http://127.0.0.1:$port');

    await expectLater(
      repository.setRecipe(
        date: DateTime(2026, 8, 23),
        meal: 'breakfast',
        recipeId: 'recipe-1',
      ),
      throwsA(isA<MealPlanQueuedException>()),
    );

    final retryServer = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      port,
    );
    addTearDown(() => retryServer.close(force: true));
    retryServer.listen((request) async {
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
      request.response.write(jsonEncode({'ok': true}));
      await request.response.close();
    });

    await repository.syncPendingChanges();

    expect(requests.single.method, 'PUT');
    expect(requests.single.path, '/meal-plan/2026-08-23/breakfast');
    expect(jsonDecode(requests.single.body), {
      'slotType': 'recipe',
      'recipeId': 'recipe-1',
    });
    expect(repository.syncStatus.phase, MealPlanSyncPhase.synced);
    expect(repository.syncStatus.pendingCount, 0);
  });

  test('keeps queued writes after repository restart', () async {
    final unavailableServer = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final port = unavailableServer.port;
    await unavailableServer.close(force: true);
    repository = ApiMealPlanRepository(baseUrl: 'http://127.0.0.1:$port');

    await expectLater(
      repository.setEmpty(date: DateTime(2026, 8, 23), meal: 'dinner'),
      throwsA(isA<MealPlanQueuedException>()),
    );

    repository = ApiMealPlanRepository(baseUrl: 'http://127.0.0.1:$port');
    final retryServer = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      port,
    );
    addTearDown(() => retryServer.close(force: true));
    retryServer.listen((request) async {
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
      request.response.write(jsonEncode({'ok': true}));
      await request.response.close();
    });

    await repository.syncPendingChanges();

    expect(requests.single.method, 'PUT');
    expect(requests.single.path, '/meal-plan/2026-08-23/dinner');
    expect(jsonDecode(requests.single.body), {'slotType': 'empty'});
    expect(repository.syncStatus.phase, MealPlanSyncPhase.synced);
  });

  test('reports blocked queued writes when backend rejects them', () async {
    await server.close(force: true);
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    repository = ApiMealPlanRepository(
      baseUrl: 'http://${server.address.host}:${server.port}',
    );

    final port = server.port;
    await server.close(force: true);
    await expectLater(
      repository.setRecipe(
        date: DateTime(2026, 8, 23),
        meal: 'breakfast',
        recipeId: 'recipe-1',
      ),
      throwsA(isA<MealPlanQueuedException>()),
    );

    server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    server.listen((request) async {
      request.response.statusCode = HttpStatus.unauthorized;
      request.response.write(jsonEncode({'message': 'nope'}));
      await request.response.close();
    });

    await expectLater(
      repository.syncPendingChanges(),
      throwsA(isA<MealPlanSaveException>()),
    );
    expect(repository.syncStatus.phase, MealPlanSyncPhase.blocked);
    expect(repository.syncStatus.pendingCount, 1);
    expect(repository.syncStatus.message, contains('Token'));
  });

  test('closes a planned day', () async {
    final result = await repository.closeDay(DateTime(2026, 8, 23));

    expect(result.plannedFor, DateTime(2026, 8, 23));
    expect(result.recordedCount, 2);
    expect(result.skippedCount, 1);
    expect(requests.single.method, 'POST');
    expect(requests.single.path, '/meal-plan/close-day/2026-08-23');
  });

  test('keeps meal plan empty when backend is unavailable', () async {
    final unavailableServer = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final port = unavailableServer.port;
    await unavailableServer.close(force: true);
    repository = ApiMealPlanRepository(baseUrl: 'http://127.0.0.1:$port');

    final today = DateTime.now();
    final slots = await repository.getRange(from: today, to: today);

    expect(slots, isEmpty);
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
