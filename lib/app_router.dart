import 'package:go_router/go_router.dart';
import 'package:recipe_capturer/data/file_recipe_repository.dart';
import 'package:recipe_capturer/data/recipe_repository.dart';
import 'package:recipe_capturer/domain/recipe.dart';
import 'package:recipe_capturer/ui/pages/new_recipe_page.dart';
import 'package:recipe_capturer/ui/pages/recipe_details_page.dart';
import 'package:recipe_capturer/ui/pages/recipe_list_page.dart';

final repo = FileRecipeRepository();

final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => RecipeListPage(title: 'Rezepte', repo: repo),
    ),
    GoRoute(
      path: '/details',
      builder: (context, state) {
        final recipe = state.extra as Recipe;
        return RecipeDetailsPage(recipe: recipe, repo: repo);
      },
    ),
    GoRoute(
      path: '/new',
      builder: (context, state) =>
          NewRecipePage(title: 'Neues Rezept', repo: repo),
    ),
    GoRoute(
      path: '/edit',
      builder: (context, state) {
        final recipe = state.extra as Recipe;
        return NewRecipePage(
          title: 'Rezept bearbeiten',
          repo: repo,
          initialRecipe: recipe,
        );
      },
    ),
  ],
);

RecipeRepository get recipeRepository => repo;
