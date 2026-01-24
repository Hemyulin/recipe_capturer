import 'package:go_router/go_router.dart';
import 'package:recipe_capturer/data/in_memory_recipe_repository.dart';
import 'package:recipe_capturer/new_recipe_page.dart';
import 'package:recipe_capturer/recipe_list_page.dart';

final repo = InMemoryRecipeRepository();

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
