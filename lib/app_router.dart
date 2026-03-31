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
        final extra = state.extra;

        if (extra is List<String>) {
          return ImportRecipePage(imagePaths: extra);
        }

        final data = extra as Map<String, dynamic>? ?? const {};
        final imagePaths = (data['imagePaths'] as List<dynamic>? ?? const [])
            .cast<String>();
        final sharedText = data['sharedText'] as String?;
        final pickImagesFirst = data['pickImagesFirst'] == true;

        return ImportRecipePage(
          imagePaths: imagePaths,
          sharedText: sharedText,
          pickImagesFirst: pickImagesFirst,
        );
      },
    ),
    GoRoute(
      path: '/new',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;

        return NewRecipePage(
          title: 'Neues Rezept',
          repo: repo,
          initialTitle: extra?['title'] as String?,
          initialIngredients: extra?['ingredientsText'] as String?,
          initialInstructions: extra?['instructions'] as String?,
          initialImagePaths: (extra?['imagePaths'] as List<dynamic>?)
              ?.cast<String>(),
          isImportReview: extra?['fromImport'] == true,
          initialOcrRawText: extra?['ocrRawText'] as String?,
          isSharedLinkImport: extra?['fromSharedLink'] == true,
          initialSharedLinkText: extra?['sharedLinkText'] as String?,
          initialSourceUrl: extra?['sourceUrl'] as String?,
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
