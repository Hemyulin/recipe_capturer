import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_capturer/domain/recipe.dart';

void main() {
  test('Recipe.create trims title', () {
    final recipe = Recipe.create('  test title       ');
    expect(recipe.title, 'test title');
  });

  test('Recipe.create throws on empty title', () {
    expect(() => Recipe.create('     '), throwsArgumentError);
  });

  //   test('Recipe.create contains creation timestamp', () {
  //     DateTime fixed = DateTime(2026, 1, 1);

  //     final recipe = Recipe.create('x', now: fixed);
  //     expect(recipe.createdAt, fixed);
  //   });
}
