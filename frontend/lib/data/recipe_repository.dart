import '../domain/recipe.dart';

class RecipeSaveException implements Exception {
  const RecipeSaveException(this.userMessage);

  final String userMessage;

  @override
  String toString() => userMessage;
}

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

abstract interface class RecipeAiImportRepository {
  Future<Recipe> importFromImage({required String imagePath});

  Future<Recipe> importFromImages({required List<String> imagePaths});
}
