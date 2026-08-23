import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cookbuk/data/in_memory_meal_plan_repository.dart';
import 'package:cookbuk/data/in_memory_recipe_repository.dart';
import 'package:cookbuk/domain/recipe.dart';
import 'package:cookbuk/ui/pages/new_recipe_page.dart';
import 'package:cookbuk/ui/pages/shopping_page.dart';
import 'package:cookbuk/ui/pages/today_page.dart';
import 'package:cookbuk/ui/pages/week_page.dart';

void main() {
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

  testWidgets('clears a Today meal after revealing trash action', (
    WidgetTester tester,
  ) async {
    final repo = InMemoryRecipeRepository();
    for (final recipe in testRecipes) {
      await repo.add(recipe);
    }

    final mealPlanRepo = InMemoryMealPlanRepository();

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

    expect(find.text('Nichts geplant'), findsOneWidget);
    final slots = await mealPlanRepo.getRange(
      from: DateTime.now(),
      to: DateTime.now(),
    );
    expect(slots.singleWhere((slot) => slot.meal == 'breakfast').isEmpty, true);
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

    await tester.drag(find.text('Mittagessen'), const Offset(180, 0));
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

  testWidgets('closes Today from the options menu', (
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
    await mealPlanRepo.setLeftovers(date: selectedDate, meal: 'lunch');

    await tester.pumpWidget(
      MaterialApp(
        home: TodayPage(repo: repo, mealPlanRepo: mealPlanRepo),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tag abschließen'));
    await tester.pumpAndSettle();

    expect(find.text('1 Mahlzeit gezählt.'), findsOneWidget);
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

    await tester.drag(find.text('Mittagessen'), const Offset(180, 0));
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

  testWidgets('builds a shopping list from planned recipes', (
    WidgetTester tester,
  ) async {
    final repo = InMemoryRecipeRepository();
    final mealPlanRepo = InMemoryMealPlanRepository();
    final secondOatRecipe = Recipe.create(
      'Oatmeal Buns',
      ingredients: const [
        RecipeIngredient(name: 'Haferflocken', quantity: '80', unit: 'g'),
        RecipeIngredient(name: 'Magerquark', quantity: '250', unit: 'g'),
      ],
      instructions: const ['Mischen und backen.'],
      tags: const ['breakfast'],
    );

    await repo.add(testRecipes.first);
    await repo.add(secondOatRecipe);

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

    await tester.pumpWidget(
      MaterialApp(
        home: ShoppingPage(repo: repo, mealPlanRepo: mealPlanRepo),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Einkauf'), findsOneWidget);
    expect(find.text('2 Rezepte, 3 Zutaten'), findsOneWidget);
    expect(find.text('200 g Haferflocken'), findsOneWidget);
    expect(find.text('250 g Magerquark'), findsOneWidget);
    expect(find.text('1 Banane'), findsOneWidget);

    await tester.tap(find.text('200 g Haferflocken'));
    await tester.pumpAndSettle();

    expect(find.text('1/3'), findsOneWidget);
  });
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
