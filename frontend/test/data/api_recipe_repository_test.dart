import 'dart:convert';
import 'dart:io';

import 'package:cookbuk/data/api_recipe_repository.dart';
import 'package:cookbuk/data/recipe_repository.dart';
import 'package:cookbuk/domain/recipe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late HttpServer server;
  late ApiRecipeRepository repository;
  final requests = <_RequestLog>[];

  setUp(() async {
    requests.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    repository = ApiRecipeRepository(
      baseUrl: 'http://${server.address.host}:${server.port}',
    );

    server.listen((request) async {
      final body = await utf8.decoder.bind(request).join();
      requests.add(
        _RequestLog(
          method: request.method,
          path: request.uri.path,
          body: body,
          token: request.headers.value('x-cookbuk-token'),
        ),
      );

      request.response.headers.contentType = ContentType.json;
      if (request.method == 'GET' && request.uri.path == '/recipes') {
        request.response.write(jsonEncode([_recipeJson()]));
      } else if (request.method == 'POST' && request.uri.path == '/recipes') {
        request.response.write(jsonEncode(_recipeJson()));
      } else if (request.method == 'PATCH' &&
          request.uri.path.startsWith('/recipes/')) {
        request.response.write(jsonEncode(_recipeJson()));
      } else if (request.method == 'POST' &&
          request.uri.path == '/recipes/oatmeal-buns/image') {
        request.response.write(
          jsonEncode(
            _recipeJson(imagePaths: const ['/images/oatmeal-buns.jpg']),
          ),
        );
      } else if (request.method == 'POST' &&
          request.uri.path == '/recipes/imports/photo') {
        request.response.write(
          jsonEncode({
            'title': 'Foto Pasta',
            'notes': 'Aus Foto erkannt.',
            'servings': 2,
            'season': '',
            'prepTimeMinutes': 10,
            'cookTimeMinutes': 20,
            'ingredients': [
              {'name': 'Pasta', 'quantity': '200', 'unit': 'g'},
            ],
            'instructions': ['Kochen.', 'Servieren.'],
            'tags': ['dinner', 'quick'],
            'confidenceNotes': ['Menge war schwer lesbar.'],
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

  test('reads recipes from the backend', () async {
    final recipes = await repository.getAll();

    expect(recipes, hasLength(1));
    expect(recipes.single.title, 'Oatmeal Buns');
    expect(
      recipes.single.mainImagePath,
      'http://${server.address.host}:${server.port}/images/oatmeal-buns.jpg',
    );
    expect(requests.single.method, 'GET');
    expect(requests.single.path, '/recipes');
  });

  test('sends shared token headers when configured', () async {
    repository = ApiRecipeRepository(
      baseUrl: 'http://${server.address.host}:${server.port}',
      sharedToken: 'secret',
    );

    await repository.getAll();

    expect(requests.single.token, 'secret');
  });

  test('tries the next backend URL when the first is unavailable', () async {
    final unavailableServer = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final unavailablePort = unavailableServer.port;
    await unavailableServer.close(force: true);
    repository = ApiRecipeRepository(
      baseUrls: [
        'http://127.0.0.1:$unavailablePort',
        'http://${server.address.host}:${server.port}',
      ],
    );

    final recipes = await repository.getAll();

    expect(recipes, hasLength(1));
    expect(
      recipes.single.mainImagePath,
      'http://${server.address.host}:${server.port}/images/oatmeal-buns.jpg',
    );
    expect(requests.single.path, '/recipes');
  });

  test('writes backend-safe recipe payloads', () async {
    final recipe = Recipe.create(
      'Oatmeal Buns',
      ingredients: const [
        RecipeIngredient(name: 'Oatmeal', quantity: '200', unit: 'g'),
      ],
      instructions: const ['Mix everything.', 'Bake until golden.'],
      tags: const ['One pot', 'Breakfast'],
      isFavorite: true,
      imagePaths: const ['assets/demo_recipes/oatmeal_buns.png'],
      servings: 4,
      season: 'Ganzjaehrig',
      prepTimeMinutes: 10,
      cookTimeMinutes: 20,
      notes: 'No flour.',
    );

    final addedRecipe = await repository.add(recipe);
    final updatedRecipe = await repository.update(recipe);
    await repository.deleteById(recipe.id);

    expect(addedRecipe.title, 'Oatmeal Buns');
    expect(updatedRecipe.title, 'Oatmeal Buns');

    expect(requests.map((request) => request.method), [
      'POST',
      'PATCH',
      'DELETE',
    ]);
    expect(requests[1].path, '/recipes/${recipe.id}');
    expect(requests[2].path, '/recipes/${recipe.id}');

    for (final request in requests.take(2)) {
      final payload = jsonDecode(request.body) as Map<String, dynamic>;
      expect(payload['title'], 'Oatmeal Buns');
      expect(payload['season'], 'Ganzjaehrig');
      expect(payload['ingredients'], isA<List<dynamic>>());
      expect(payload.containsKey('id'), isFalse);
      expect(payload.containsKey('createdAt'), isFalse);
      expect(payload.containsKey('cookCount'), isFalse);
      expect(payload.containsKey('cookEvents'), isFalse);
      expect(payload.containsKey('lastCookedAt'), isFalse);
    }
  });

  test('uploads recipe images to the backend', () async {
    repository = ApiRecipeRepository(
      baseUrl: 'http://${server.address.host}:${server.port}',
      sharedToken: 'secret',
    );
    final file = await File(
      '${Directory.systemTemp.path}/cookbuk_api_upload_test.jpg',
    ).writeAsString('fake image');

    final recipe = await repository.uploadImage(
      recipeId: 'oatmeal-buns',
      imagePath: file.path,
    );

    expect(requests.single.method, 'POST');
    expect(requests.single.path, '/recipes/oatmeal-buns/image');
    expect(requests.single.token, 'secret');
    expect(requests.single.body, contains('form-data'));
    expect(
      recipe.mainImagePath,
      'http://${server.address.host}:${server.port}/images/oatmeal-buns.jpg',
    );

    await file.delete();
  });

  test('imports recipe drafts from photos', () async {
    final file = await File(
      '${Directory.systemTemp.path}/cookbuk_api_import_test.jpg',
    ).writeAsString('fake image');

    final draft = await repository.importFromImage(imagePath: file.path);

    expect(requests.single.method, 'POST');
    expect(requests.single.path, '/recipes/imports/photo');
    expect(requests.single.body, contains('form-data'));
    expect(draft.title, 'Foto Pasta');
    expect(draft.ingredients.single.name, 'Pasta');
    expect(draft.instructions, ['Kochen.', 'Servieren.']);
    expect(draft.tags, contains('quick'));
    expect(draft.mainImagePath, file.path);

    await file.delete();
  });

  test(
    'does not fake successful recipe writes when backend is unavailable',
    () async {
      final unavailableServer = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final port = unavailableServer.port;
      await unavailableServer.close(force: true);
      repository = ApiRecipeRepository(baseUrl: 'http://127.0.0.1:$port');

      await expectLater(
        repository.add(Recipe.create('Offline Pasta')),
        throwsA(
          isA<RecipeSaveException>().having(
            (error) => error.userMessage,
            'userMessage',
            contains('Pi nicht erreichbar'),
          ),
        ),
      );
    },
  );

  test('falls back to demo recipes when backend is unavailable', () async {
    final unavailableServer = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    final port = unavailableServer.port;
    await unavailableServer.close(force: true);
    repository = ApiRecipeRepository(baseUrl: 'http://127.0.0.1:$port');

    final recipes = await repository.getAll();

    expect(recipes.length, greaterThanOrEqualTo(5));
    expect(
      recipes.map((recipe) => recipe.title),
      contains('Oatmeal Buns ohne Mehl'),
    );
    expect(recipes.first.mainImagePath, startsWith('assets/demo_recipes/'));
  });
}

Map<String, dynamic> _recipeJson({List<String>? imagePaths}) {
  return {
    'id': 'oatmeal-buns',
    'title': 'Oatmeal Buns',
    'createdAt': '2026-08-23T10:00:00.000Z',
    'ingredients': [
      {'name': 'Oatmeal', 'quantity': '200', 'unit': 'g'},
    ],
    'instructions': ['Mix everything.', 'Bake until golden.'],
    'tags': ['One pot', 'Breakfast'],
    'isFavorite': true,
    'imagePaths': imagePaths ?? ['/images/oatmeal-buns.jpg'],
    'servings': 4,
    'season': 'Ganzjaehrig',
    'prepTimeMinutes': 10,
    'cookTimeMinutes': 20,
    'notes': 'No flour.',
    'cookEvents': [],
  };
}

class _RequestLog {
  const _RequestLog({
    required this.method,
    required this.path,
    required this.body,
    required this.token,
  });

  final String method;
  final String path;
  final String body;
  final String? token;
}
