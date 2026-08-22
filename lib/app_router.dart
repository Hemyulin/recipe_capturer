import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_capturer/data/file_recipe_repository.dart';
import 'package:recipe_capturer/data/recipe_repository.dart';
import 'package:recipe_capturer/domain/recipe.dart';
import 'package:recipe_capturer/ui/pages/main_shell_page.dart';
import 'package:recipe_capturer/ui/pages/new_recipe_page.dart';
import 'package:recipe_capturer/ui/pages/placeholder_page.dart';
import 'package:recipe_capturer/ui/pages/recipe_details_page.dart';
import 'package:recipe_capturer/ui/pages/recipe_list_page.dart';
import 'package:recipe_capturer/ui/pages/today_page.dart';

final repo = FileRecipeRepository();

final router = GoRouter(
  initialLocation: '/today',
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          MainShellPage(location: state.uri.path, child: child),
      routes: [
        GoRoute(path: '/', redirect: (_, _) => '/today'),
        GoRoute(
          path: '/today',
          builder: (context, state) => TodayPage(repo: repo),
        ),
        GoRoute(
          path: '/week',
          builder: (context, state) => const PlaceholderPage(
            title: 'Woche',
            icon: Icons.calendar_view_week_outlined,
            message:
                'Der Wochenplan bekommt später Frühstück, Mittagessen und Abendessen pro Tag.',
          ),
        ),
        GoRoute(
          path: '/recipes',
          builder: (context, state) =>
              RecipeListPage(title: 'Rezepte', repo: repo),
        ),
        GoRoute(
          path: '/shopping',
          builder: (context, state) => const PlaceholderPage(
            title: 'Einkauf',
            icon: Icons.shopping_basket_outlined,
            message:
                'Die Einkaufsliste wird später aus geplanten Rezepten aggregiert.',
          ),
        ),
      ],
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
