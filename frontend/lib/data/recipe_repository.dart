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

class RecipePageQuery {
  const RecipePageQuery({
    this.search = '',
    this.favoritesOnly = false,
    this.needsReviewOnly = false,
    this.season,
    this.maxTotalTimeMinutes,
    this.tag,
    this.limit = 20,
    this.offset = 0,
  });

  final String search;
  final bool favoritesOnly;
  final bool needsReviewOnly;
  final String? season;
  final int? maxTotalTimeMinutes;
  final String? tag;
  final int limit;
  final int offset;
}

class RecipePageResult {
  const RecipePageResult({
    required this.items,
    required this.total,
    required this.totalCount,
    required this.needsReviewCount,
    required this.seasons,
    required this.tags,
  });

  final List<Recipe> items;
  final int total;
  final int totalCount;
  final int needsReviewCount;
  final List<String> seasons;
  final List<String> tags;
}

abstract interface class PaginatedRecipeRepository {
  Future<RecipePageResult> getPage(RecipePageQuery query);
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

abstract interface class RecipeAiPolishRepository {
  Future<Recipe> polishRecipe(Recipe recipe);
}

abstract interface class RecipeAiImageRepository {
  Future<String> generateRecipeImage(Recipe recipe);
}
