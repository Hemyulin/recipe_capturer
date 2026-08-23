import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cookbuk/data/api_meal_plan_repository.dart';
import 'package:cookbuk/data/api_recipe_repository.dart';
import 'package:cookbuk/data/meal_plan_repository.dart';
import 'package:cookbuk/data/recipe_repository.dart';
import 'package:cookbuk/domain/recipe.dart';
import 'package:cookbuk/ui/pages/main_shell_page.dart';
import 'package:cookbuk/ui/pages/new_recipe_page.dart';
import 'package:cookbuk/ui/pages/placeholder_page.dart';
import 'package:cookbuk/ui/pages/recipe_details_page.dart';
import 'package:cookbuk/ui/pages/recipe_list_page.dart';
import 'package:cookbuk/ui/pages/today_page.dart';
import 'package:cookbuk/ui/pages/week_page.dart';

const apiBaseUrl = String.fromEnvironment(
  'COOKBUK_API_BASE_URL',
  defaultValue: 'http://127.0.0.1:3000',
);

final repo = ApiRecipeRepository(baseUrl: apiBaseUrl);
final mealPlanRepo = ApiMealPlanRepository(baseUrl: apiBaseUrl);

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
          builder: (context, state) =>
              TodayPage(repo: repo, mealPlanRepo: mealPlanRepo),
        ),
        GoRoute(
          path: '/week',
          builder: (context, state) =>
              WeekPage(repo: repo, mealPlanRepo: mealPlanRepo),
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
MealPlanRepository get mealPlanRepository => mealPlanRepo;
