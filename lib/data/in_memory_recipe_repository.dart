import 'package:recipe_capturer/data/recipe_repository.dart';
import 'package:recipe_capturer/domain/recipe.dart';

class InMemoryRecipeRepository implements RecipeRepository {
  final List<Recipe> _recipe = [];

  @override
  Future<List<Recipe>> getAll() async {
    return _recipe.reversed.toList();
  }

  @override
  Future<void> add(Recipe recipe) async {
    _recipe.add(recipe);
  }

  @override
  Future<void> deleteById(String id) async {
    _recipe.removeWhere((r) => r.id == id);
  }
}
