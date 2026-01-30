import '../domain/recipe.dart';

abstract interface class RecipeRepository {
  Future<List<Recipe>> getAll();

  Future<void> add(Recipe recipe);

  Future<void> deleteById(String id);
}
