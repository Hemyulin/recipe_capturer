import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_capturer/domain/recipe.dart';

void main() {
  test('Recipe.create trims title', () {
    final recipe = Recipe.create('  test title       ');
    expect(recipe.title, 'test title');
  });

  test('Recipe.create allows empty string', () {
    final recipe = Recipe.create('');
    expect(recipe.title, '');
  });

  //   test('Recipe.create contains creation timestamp', () {
  //     DateTime fixed = DateTime(2026, 1, 1);

  //     final recipe = Recipe.create('x', now: fixed);
  //     expect(recipe.createdAt, fixed);
  //   });
}
