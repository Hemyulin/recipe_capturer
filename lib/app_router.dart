import 'package:go_router/go_router.dart';
import 'package:recipe_capturer/data/file_recipe_repository.dart';
import 'package:recipe_capturer/domain/recipe.dart';
import 'package:recipe_capturer/ui/pages/import_recipe_page.dart';
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
      path: '/import',
      builder: (context, state) {
        final imagePaths = state.extra as List<String>;
        return ImportRecipePage(imagePaths: imagePaths);
      },
    ),
    GoRoute(
      path: '/new',
      builder: (context, state) {
        final extra = state.extra as Map<String, String?>?;
        return NewRecipePage(
          title: 'Neue Rezeptenseite',
          repo: repo,
          initialTitle: extra?['title'],
          initialIngredients: extra?['ingredientsText'],
          initialInstructions: extra?['instructions'],
        );
      },
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
