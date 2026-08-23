import '../domain/recipe.dart';

abstract interface class RecipeRepository {
  Future<List<Recipe>> getAll();

  Future<Recipe> add(Recipe recipe);

  Future<void> deleteById(String id);

  Future<Recipe> update(Recipe recipe);
}

abstract interface class RecipeImageRepository {
  Future<Recipe> uploadImage({
    required String recipeId,
    required String imagePath,
  });
}
