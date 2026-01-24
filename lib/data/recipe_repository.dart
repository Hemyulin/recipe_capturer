import '../domain/recipe.dart';

abstract interface class RecipeRepository {
  List<Recipe> getAll();

  void add(Recipe recipe);
}
