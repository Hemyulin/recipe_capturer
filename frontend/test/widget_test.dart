import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cookbuk/data/in_memory_meal_plan_repository.dart';
import 'package:cookbuk/data/in_memory_recipe_repository.dart';
import 'package:cookbuk/data/meal_plan_repository.dart';
import 'package:cookbuk/domain/meal_plan_slot.dart';
import 'package:cookbuk/domain/recipe.dart';
import 'package:cookbuk/ui/pages/new_recipe_page.dart';
import 'package:cookbuk/ui/pages/shopping_page.dart';
import 'package:cookbuk/ui/pages/status_page.dart';
import 'package:cookbuk/ui/pages/today_page.dart';
import 'package:cookbuk/ui/pages/week_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var clipboardText = '';

  setUp(() {
    clipboardText = '';
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          switch (call.method) {
            case 'Clipboard.setData':
              final data = call.arguments as Map<dynamic, dynamic>;
              clipboardText = data['text'] as String? ?? '';
              return null;
            case 'Clipboard.getData':
              return {'text': clipboardText};
            case 'Clipboard.hasStrings':
              return {'value': clipboardText.isNotEmpty};
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  testWidgets('shows Today as the home screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TodayPage(
          repo: InMemoryRecipeRepository(),
          mealPlanRepo: InMemoryMealPlanRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Heute'), findsWidgets);
    expect(find.text('Was essen wir heute?'), findsNothing);
    expect(find.text('Frühstück'), findsOneWidget);
    expect(find.text('Mittagessen'), findsOneWidget);
    expect(find.text('Abendessen'), findsOneWidget);
  });

  testWidgets('shows manual recipe form', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NewRecipePage(
          title: 'Neues Rezept',
          repo: InMemoryRecipeRepository(),
        ),
      ),
    );

    expect(find.text('Neues Rezept'), findsOneWidget);
  });

  testWidgets('shows AI import review framing for imported drafts', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: NewRecipePage(
          title: 'KI-Import prüfen',
          repo: InMemoryRecipeRepository(),
          initialRecipe: Recipe.create(
            'Foto Pasta',
            ingredients: const [RecipeIngredient(name: 'Pasta')],
            instructions: const ['Kochen.'],
            imagePaths: const ['assets/demo_recipes/pesto_pasta_peas.png'],
            confidenceNotes: const ['Menge war schwer lesbar.'],
          ),
          saveAsNew: true,
          isAiImportReview: true,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('KI-Import prüfen'), findsOneWidget);
    expect(find.text('Bitte kurz prüfen'), findsOneWidget);
    expect(find.text('Unsichere Stellen'), findsOneWidget);
    expect(find.text('Menge war schwer lesbar.'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Rezept speichern'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Rezept speichern'), findsOneWidget);
  });

  testWidgets('clears a Today meal after revealing trash action', (
    WidgetTester tester,
  ) async {
    final repo = InMemoryRecipeRepository();
    for (final recipe in testRecipes) {
      await repo.add(recipe);
    }

    final mealPlanRepo = InMemoryMealPlanRepository();
    final today = DateTime.now();
    final selectedDate = DateTime(today.year, today.month, today.day);
    await mealPlanRepo.setRecipe(
      date: selectedDate,
      meal: 'breakfast',
      recipeId: testRecipes.first.id,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TodayPage(repo: repo, mealPlanRepo: mealPlanRepo),
      ),
    );
    await tester.pumpAndSettle();

    await tester.drag(find.text('Frühstück'), const Offset(-180, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    expect(find.text('Nichts geplant'), findsNWidgets(3));
    final slots = await mealPlanRepo.getRange(
      from: DateTime.now(),
      to: DateTime.now(),
    );
    expect(slots.singleWhere((slot) => slot.meal == 'breakfast').isEmpty, true);
  });

  testWidgets('does not auto-fill Today meals from recipe tags', (
    WidgetTester tester,
  ) async {
    final repo = InMemoryRecipeRepository();
    for (final recipe in testRecipes) {
      await repo.add(recipe);
    }

    await tester.pumpWidget(
      MaterialApp(
        home: TodayPage(repo: repo, mealPlanRepo: InMemoryMealPlanRepository()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Nichts geplant'), findsNWidgets(3));
    expect(find.text(testRecipes.first.title), findsNothing);
  });

  testWidgets('shows preparation tasks from upcoming planned recipes', (
    WidgetTester tester,
  ) async {
    final repo = InMemoryRecipeRepository();
    final mealPlanRepo = InMemoryMealPlanRepository();
    final lentils = Recipe.create(
      'Madjadra',
      ingredients: const [
        RecipeIngredient(name: 'Linsen', quantity: '250', unit: 'g'),
      ],
      preparationTasks: const ['Linsen am Vormittag in Wasser legen.'],
      instructions: const ['Zwiebeln langsam braten.'],
      tags: const ['dinner'],
      servings: 4,
      prepTimeMinutes: 15,
      cookTimeMinutes: 45,
    );
    await repo.add(lentils);

    final today = DateTime.now();
    final selectedDate = DateTime(today.year, today.month, today.day);
    await mealPlanRepo.setRecipe(
      date: selectedDate.add(const Duration(days: 1)),
      meal: 'dinner',
      recipeId: lentils.id,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TodayPage(repo: repo, mealPlanRepo: mealPlanRepo),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Heute vorbereiten'), findsOneWidget);
    expect(find.textContaining('Madjadra'), findsOneWidget);
    expect(find.textContaining('Morgen · Abendessen'), findsOneWidget);
    expect(
      find.textContaining('Linsen am Vormittag in Wasser legen.'),
      findsOneWidget,
    );
  });

  testWidgets('sets leftovers for a Today meal', (WidgetTester tester) async {
    final repo = InMemoryRecipeRepository();
    final mealPlanRepo = InMemoryMealPlanRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: TodayPage(repo: repo, mealPlanRepo: mealPlanRepo),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nichts geplant').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reste').first);
    await tester.pumpAndSettle();

    expect(find.text('Reste'), findsOneWidget);
    expect(find.text('Keine Rezeptauswahl für diese Mahlzeit'), findsNothing);
    final slots = await mealPlanRepo.getRange(
      from: DateTime.now(),
      to: DateTime.now(),
    );
    expect(
      slots.singleWhere((slot) => slot.meal == 'breakfast').isLeftovers,
      true,
    );
  });

  testWidgets('sets a recipe for a Today meal', (WidgetTester tester) async {
    final repo = InMemoryRecipeRepository();
    final mealPlanRepo = InMemoryMealPlanRepository();
    for (final recipe in testRecipes) {
      await repo.add(recipe);
    }

    await tester.pumpWidget(
      MaterialApp(
        home: TodayPage(repo: repo, mealPlanRepo: mealPlanRepo),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nichts geplant').at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oatmeal mit Banane und Blaubeeren').last);
    await tester.pumpAndSettle();

    final slots = await mealPlanRepo.getRange(
      from: DateTime.now(),
      to: DateTime.now(),
    );
    final lunch = slots.singleWhere((slot) => slot.meal == 'lunch');
    expect(lunch.isRecipe, true);
    expect(lunch.recipeId, testRecipes.first.id);
  });

  testWidgets('updates preparation after setting a Today meal', (
    WidgetTester tester,
  ) async {
    final repo = InMemoryRecipeRepository();
    final mealPlanRepo = InMemoryMealPlanRepository();
    final prepRecipe = Recipe.create(
      'Linsen Dal',
      ingredients: const [
        RecipeIngredient(name: 'Linsen', quantity: '250', unit: 'g'),
      ],
      preparationTasks: const ['Linsen 3 Stunden einweichen lassen.'],
      instructions: const ['Kochen.'],
      tags: const ['dinner'],
    );
    await repo.add(prepRecipe);

    await tester.pumpWidget(
      MaterialApp(
        home: TodayPage(repo: repo, mealPlanRepo: mealPlanRepo),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Heute vorbereiten'), findsNothing);

    await tester.tap(find.text('Nichts geplant').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Linsen Dal').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Heute vorbereiten'), findsOneWidget);
    expect(find.textContaining('Linsen 3 Stunden'), findsOneWidget);
  });

  testWidgets('repeats a Today recipe through current Sunday', (
    WidgetTester tester,
  ) async {
    final repo = InMemoryRecipeRepository();
    final mealPlanRepo = InMemoryMealPlanRepository();
    await repo.add(testRecipes.first);

    final today = DateTime.now();
    final selectedDate = DateTime(today.year, today.month, today.day);
    await mealPlanRepo.setRecipe(
      date: selectedDate,
      meal: 'breakfast',
      recipeId: testRecipes.first.id,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: TodayPage(repo: repo, mealPlanRepo: mealPlanRepo),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Wiederholen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eintragen'));
    await tester.pumpAndSettle();

    final endOfWeek = selectedDate.add(
      Duration(days: 7 - selectedDate.weekday),
    );
    final slots = await mealPlanRepo.getRange(
      from: selectedDate,
      to: endOfWeek,
    );
    final repeatedBreakfasts = slots.where(
      (slot) =>
          slot.meal == 'breakfast' &&
          slot.recipeId == testRecipes.first.id &&
          slot.plannedFor.weekday == selectedDate.weekday,
    );
    expect(repeatedBreakfasts, hasLength(1));
  });

  testWidgets('adds text extras to a Today meal', (WidgetTester tester) async {
    final repo = InMemoryRecipeRepository();
    final mealPlanRepo = InMemoryMealPlanRepository();
    await repo.add(testRecipes[1]);

    await tester.pumpWidget(
      MaterialApp(
        home: TodayPage(repo: repo, mealPlanRepo: mealPlanRepo),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Beilagen bearbeiten').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Brot'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hummus'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rezept'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kichererbsen-Couscous-Bowl').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fertig'));
    await tester.pumpAndSettle();

    expect(
      find.text('+ Kichererbsen-Couscous-Bowl · Brot · Hummus'),
      findsOneWidget,
    );

    final slots = await mealPlanRepo.getRange(
      from: DateTime.now(),
      to: DateTime.now(),
    );
    expect(slots.singleWhere((slot) => slot.meal == 'breakfast').extras, [
      'Brot',
      'Hummus',
    ]);
    expect(
      slots.singleWhere((slot) => slot.meal == 'breakfast').recipeExtraIds,
      [testRecipes[1].id],
    );
  });

  testWidgets('does not show close-day action on Today', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: TodayPage(
          repo: InMemoryRecipeRepository(),
          mealPlanRepo: InMemoryMealPlanRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Tag abschließen'), findsNothing);
    expect(find.byIcon(Icons.more_vert), findsNothing);
  });

  testWidgets('filters recipes in the Today meal picker', (
    WidgetTester tester,
  ) async {
    final repo = InMemoryRecipeRepository();
    for (final recipe in testRecipes) {
      await repo.add(recipe);
    }

    await tester.pumpWidget(
      MaterialApp(
        home: TodayPage(repo: repo, mealPlanRepo: InMemoryMealPlanRepository()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Nichts geplant').at(1));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'oatmeal');
    await tester.pumpAndSettle();

    final picker = find.byType(BottomSheet);
    expect(
      find.descendant(of: picker, matching: find.text('Reste')),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: picker,
        matching: find.text('Oatmeal mit Banane und Blaubeeren'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: picker,
        matching: find.text('Schnelles Chicken Curry'),
      ),
      findsNothing,
    );
  });

  testWidgets('sets a recipe in the Week planner', (WidgetTester tester) async {
    final repo = InMemoryRecipeRepository();
    final mealPlanRepo = InMemoryMealPlanRepository();
    for (final recipe in testRecipes) {
      await repo.add(recipe);
    }

    await tester.pumpWidget(
      MaterialApp(
        home: WeekPage(repo: repo, mealPlanRepo: mealPlanRepo),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Woche'), findsOneWidget);
    await tester.tap(find.text('Nichts geplant').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Oatmeal mit Banane und Blaubeeren').last);
    await tester.pumpAndSettle();

    final today = DateTime.now();
    final selectedDate = DateTime(today.year, today.month, today.day);
    final slots = await mealPlanRepo.getRange(
      from: selectedDate,
      to: selectedDate,
    );
    final breakfast = slots.singleWhere((slot) => slot.meal == 'breakfast');
    expect(breakfast.isRecipe, true);
    expect(breakfast.recipeId, testRecipes.first.id);
  });

  testWidgets('swipes the Week day strip to the next week', (
    WidgetTester tester,
  ) async {
    final repo = InMemoryRecipeRepository();
    final mealPlanRepo = InMemoryMealPlanRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: WeekPage(repo: repo, mealPlanRepo: mealPlanRepo),
      ),
    );
    await tester.pumpAndSettle();

    final today = DateTime.now();
    final weekStart = DateTime(
      today.year,
      today.month,
      today.day,
    ).subtract(Duration(days: today.weekday - 1));
    final nextWeekStart = weekStart.add(const Duration(days: 7));
    expect(find.text(_weekLabel(weekStart)), findsOneWidget);

    await tester.drag(
      find.text(_weekdayLabel(today.weekday)),
      const Offset(-300, 0),
    );
    await tester.pumpAndSettle();

    expect(find.text(_weekLabel(nextWeekStart)), findsOneWidget);
  });

  testWidgets('builds a shopping list from planned recipes', (
    WidgetTester tester,
  ) async {
    final repo = InMemoryRecipeRepository();
    final mealPlanRepo = InMemoryMealPlanRepository();
    final secondOatRecipe = Recipe.create(
      'Oatmeal Buns',
      ingredients: const [
        RecipeIngredient(name: 'Haferflocken', quantity: '80', unit: 'g'),
        RecipeIngredient(name: 'Ei'),
        RecipeIngredient(name: 'Eier', quantity: '2'),
        RecipeIngredient(name: 'Magerquark', quantity: '250', unit: 'g'),
        RecipeIngredient(
          name: 'Backpapier',
          quantity: '1',
          excludeFromShopping: true,
        ),
        RecipeIngredient(name: 'boiling water', quantity: '560', unit: 'ml'),
      ],
      instructions: const ['Mischen und backen.'],
      tags: const ['breakfast'],
    );
    final cakeRecipe = Recipe.create(
      'Kuchen',
      ingredients: const [
        RecipeIngredient(name: 'Ei (Gr. M)'),
        RecipeIngredient(name: 'Mehl', quantity: '0,5', unit: 'kg'),
        RecipeIngredient(name: 'Mehl', quantity: '200', unit: 'g'),
      ],
      instructions: const ['Backen.'],
      tags: const ['dessert'],
    );

    await repo.add(testRecipes.first);
    await repo.add(secondOatRecipe);
    await repo.add(cakeRecipe);

    final today = DateTime.now();
    final selectedDate = DateTime(today.year, today.month, today.day);
    await mealPlanRepo.setRecipe(
      date: selectedDate,
      meal: 'breakfast',
      recipeId: testRecipes.first.id,
    );
    await mealPlanRepo.setRecipe(
      date: selectedDate,
      meal: 'lunch',
      recipeId: secondOatRecipe.id,
    );
    await mealPlanRepo.setLeftovers(date: selectedDate, meal: 'dinner');
    await mealPlanRepo.setExtras(
      date: selectedDate,
      meal: 'dinner',
      recipeExtraIds: [cakeRecipe.id],
      extras: const [],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ShoppingPage(repo: repo, mealPlanRepo: mealPlanRepo),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Einkauf'), findsOneWidget);
    expect(find.text('2 Rezepte, 5 Zutaten'), findsOneWidget);
    expect(find.text('200 g Haferflocken'), findsOneWidget);
    expect(find.text('4 Eier'), findsOneWidget);
    expect(find.text('700 g Mehl'), findsOneWidget);
    expect(find.text('250 g Magerquark'), findsOneWidget);
    expect(find.text('1 Banane'), findsOneWidget);
    expect(find.text('1 Backpapier'), findsNothing);
    expect(find.text('560 ml boiling water'), findsNothing);

    await tester.tap(find.text('200 g Haferflocken'));
    await tester.pumpAndSettle();

    expect(find.text('1/5'), findsOneWidget);
  });

  testWidgets('copies the shopping list as plain text', (
    WidgetTester tester,
  ) async {
    final repo = InMemoryRecipeRepository();
    final mealPlanRepo = InMemoryMealPlanRepository();
    await repo.add(testRecipes.first);

    final today = DateTime.now();
    final selectedDate = DateTime(today.year, today.month, today.day);
    await mealPlanRepo.setRecipe(
      date: selectedDate,
      meal: 'breakfast',
      recipeId: testRecipes.first.id,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ShoppingPage(repo: repo, mealPlanRepo: mealPlanRepo),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Einkaufsliste kopieren'));
    await tester.pumpAndSettle();

    final clipboardData = await Clipboard.getData('text/plain');
    expect(clipboardData?.text, '1 Banane\n120 g Haferflocken');
    expect(find.text('Einkaufsliste kopiert.'), findsOneWidget);
  });

  testWidgets('shows local mode on settings page without diagnostics', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: StatusPage(mealPlanRepo: InMemoryMealPlanRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Einstellungen'), findsOneWidget);
    expect(find.text('Lokaler Modus'), findsOneWidget);
  });

  testWidgets(
    'settings page spins while testing and shows warning on failure',
    (WidgetTester tester) async {
      final repo = _FakeDiagnosticMealPlanRepository();

      await tester.pumpWidget(
        MaterialApp(home: StatusPage(mealPlanRepo: repo)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Verbindung testen'));
      await tester.pump();

      expect(find.byIcon(Icons.sync_rounded), findsWidgets);

      repo.completeConnectionTest(
        BackendConnectionTestResult(
          isConnected: false,
          checkedAt: DateTime(2026, 8, 24),
          activeBaseUrl: 'http://192.168.178.54:3000',
          message: 'Pi nicht erreichbar.',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nicht verbunden'), findsOneWidget);
      expect(find.text('Pi nicht erreichbar.'), findsOneWidget);
      expect(find.byIcon(Icons.cancel_outlined), findsWidgets);
    },
  );
}

class _FakeDiagnosticMealPlanRepository
    implements MealPlanRepository, MealPlanConnectionDiagnostics {
  final StreamController<MealPlanSyncStatus> _statusController =
      StreamController<MealPlanSyncStatus>.broadcast();
  Completer<BackendConnectionTestResult>? _connectionTest;

  void completeConnectionTest(BackendConnectionTestResult result) {
    _connectionTest?.complete(result);
  }

  @override
  String get activeBaseUrl => 'http://192.168.178.54:3000';

  @override
  List<String> get configuredBaseUrls => const [
    'http://192.168.178.54:3000',
    'http://100.125.110.4:3000',
  ];

  @override
  DateTime? get lastSuccessfulConnectionAt => null;

  @override
  int get pendingWriteCount => 0;

  @override
  MealPlanSyncStatus get syncStatus => MealPlanSyncStatus.idle;

  @override
  Stream<MealPlanSyncStatus> get syncStatusChanges => _statusController.stream;

  @override
  Future<BackendConnectionTestResult> testConnection() {
    _connectionTest = Completer<BackendConnectionTestResult>();
    return _connectionTest!.future;
  }

  @override
  Future<CloseDayResult> closeDay(DateTime date) async {
    return CloseDayResult(plannedFor: date, recordedCount: 0, skippedCount: 0);
  }

  @override
  Future<List<MealPlanSlot>> getRange({
    required DateTime from,
    required DateTime to,
  }) async {
    return const [];
  }

  @override
  Future<void> setEmpty({required DateTime date, required String meal}) async {}

  @override
  Future<void> setExtras({
    required DateTime date,
    required String meal,
    required List<String> extras,
    List<String> recipeExtraIds = const [],
  }) async {}

  @override
  Future<void> setLeftovers({
    required DateTime date,
    required String meal,
  }) async {}

  @override
  Future<void> setRecipe({
    required DateTime date,
    required String meal,
    required String recipeId,
  }) async {}

  @override
  Future<void> syncPendingChanges() async {}
}

String _weekLabel(DateTime start) {
  final end = start.add(const Duration(days: 6));
  return '${_shortDate(start)} - ${_shortDate(end)}';
}

String _shortDate(DateTime date) {
  return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.';
}

String _weekdayLabel(int weekday) {
  const labels = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
  return labels[weekday - 1];
}

final testRecipes = [
  Recipe.create(
    'Oatmeal mit Banane und Blaubeeren',
    ingredients: const [
      RecipeIngredient(name: 'Haferflocken', quantity: '120', unit: 'g'),
      RecipeIngredient(name: 'Banane', quantity: '1'),
    ],
    instructions: const ['Kochen und servieren.'],
    tags: const ['breakfast', 'quick'],
    imagePaths: const ['assets/demo_recipes/oatmeal.png'],
    servings: 2,
    prepTimeMinutes: 5,
    cookTimeMinutes: 8,
  ),
  Recipe.create(
    'Kichererbsen-Couscous-Bowl',
    ingredients: const [
      RecipeIngredient(name: 'Kichererbsen', quantity: '1', unit: 'Dose'),
      RecipeIngredient(name: 'Couscous', quantity: '180', unit: 'g'),
    ],
    instructions: const ['Alles in Schalen anrichten.'],
    tags: const ['lunch', 'quick'],
    imagePaths: const ['assets/demo_recipes/chickpea_bowl.png'],
    servings: 3,
    prepTimeMinutes: 15,
    cookTimeMinutes: 20,
  ),
  Recipe.create(
    'Schnelles Chicken Curry',
    ingredients: const [
      RecipeIngredient(name: 'Hähnchenbrust', quantity: '600', unit: 'g'),
      RecipeIngredient(name: 'Kokosmilch', quantity: '400', unit: 'ml'),
    ],
    instructions: const ['Anbraten und köcheln lassen.'],
    tags: const ['dinner', 'one_pot'],
    imagePaths: const ['assets/demo_recipes/chicken_curry.png'],
    servings: 4,
    prepTimeMinutes: 15,
    cookTimeMinutes: 30,
  ),
];
