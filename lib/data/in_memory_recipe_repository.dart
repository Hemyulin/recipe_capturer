import 'package:recipe_capturer/data/recipe_repository.dart';
import 'package:recipe_capturer/domain/recipe.dart';

class InMemoryRecipeRepository implements RecipeRepository {
  final List<Recipe> _recipe = [];

  @override
  List<Recipe> getAll() {
    return _recipe.reversed.toList();
  }

  @override
  void add(Recipe recipe) {
    _recipe.add(recipe);
  }
}
