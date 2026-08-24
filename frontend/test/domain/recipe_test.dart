import 'package:flutter_test/flutter_test.dart';
import 'package:cookbuk/domain/recipe.dart';
import 'package:cookbuk/ui/formatters/tag_label_de.dart';

void main() {
  test('Recipe.create trims title', () {
    final recipe = Recipe.create('  test title       ');
    expect(recipe.title, 'test title');
  });

  test('Recipe.create throws on empty title', () {
    expect(() => Recipe.create('     '), throwsArgumentError);
  });

  test('Recipe stores structured ingredients', () {
    final recipe = Recipe.create(
      'Pasta',
      ingredients: const [
        RecipeIngredient(name: 'Tomaten', quantity: '400', unit: 'g'),
      ],
    );

    expect(recipe.ingredients.single.name, 'Tomaten');
    expect(recipe.ingredients.single.label, '400 g Tomaten');
  });

  test('Recipe tracks cooked count and last cooked date', () {
    final cookedAt = DateTime(2026, 8, 22, 18, 30);
    final recipe = Recipe.create(
      'Pasta',
    ).withCookEvent(mealType: 'Dinner', at: cookedAt);

    expect(recipe.cookCount, 1);
    expect(recipe.lastCookedAt, cookedAt);
    expect(recipe.cookEvents.single.mealType, 'Dinner');
  });

  test('Recipe JSON keeps cooking stats', () {
    final cookedAt = DateTime(2026, 8, 22, 18, 30);
    final recipe = Recipe.create(
      'Pasta',
    ).withCookEvent(mealType: 'Lunch', at: cookedAt);

    final decoded = Recipe.fromJson(recipe.toJson());

    expect(decoded.cookCount, 1);
    expect(decoded.lastCookedAt, cookedAt);
    expect(decoded.cookEvents.single.mealType, 'Lunch');
  });

  test('recipe tag labels are German by default', () {
    expect(tagLabelDe('main'), 'Hauptgericht');
    expect(tagLabelDe('side'), 'Beilage');
    expect(tagLabelDe('vegetables'), 'Gemüse');
  });

  //   test('Recipe.create contains creation timestamp', () {
  //     DateTime fixed = DateTime(2026, 1, 1);

  //     final recipe = Recipe.create('x', now: fixed);
  //     expect(recipe.createdAt, fixed);
  //   });
}
