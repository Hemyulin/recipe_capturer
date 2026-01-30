import 'package:go_router/go_router.dart';
import 'package:recipe_capturer/data/file_recipe_repository.dart';
import 'package:recipe_capturer/ui/new_recipe_page.dart';
import 'package:recipe_capturer/ui/recipe_list_page.dart';

final repo = FileRecipeRepository();

final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => RecipeListPage(title: 'Rezepte', repo: repo),
    ),
    GoRoute(
      path: '/new',
      builder: (context, state) =>
          NewRecipePage(title: 'Neue Rezeptenseite', repo: repo),
    ),
  ],
);
