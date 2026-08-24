import 'package:go_router/go_router.dart';
import 'package:cookbuk/config/app_config.dart';
import 'package:cookbuk/data/api_meal_plan_repository.dart';
import 'package:cookbuk/data/api_recipe_repository.dart';
import 'package:cookbuk/data/meal_plan_repository.dart';
import 'package:cookbuk/data/recipe_repository.dart';
import 'package:cookbuk/domain/recipe.dart';
import 'package:cookbuk/ui/pages/main_shell_page.dart';
import 'package:cookbuk/ui/pages/new_recipe_page.dart';
import 'package:cookbuk/ui/pages/recipe_details_page.dart';
import 'package:cookbuk/ui/pages/recipe_list_page.dart';
import 'package:cookbuk/ui/pages/shopping_page.dart';
import 'package:cookbuk/ui/pages/status_page.dart';
import 'package:cookbuk/ui/pages/today_page.dart';
import 'package:cookbuk/ui/pages/week_page.dart';

final repo = ApiRecipeRepository(
  baseUrls: AppConfig.apiBaseUrls,
  sharedToken: AppConfig.sharedToken,
);
final mealPlanRepo = ApiMealPlanRepository(
  baseUrls: AppConfig.apiBaseUrls,
  sharedToken: AppConfig.sharedToken,
);

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
          builder: (context, state) => RecipeListPage(
            title: 'Rezepte',
            repo: repo,
            mealPlanRepo: mealPlanRepo,
          ),
        ),
        GoRoute(
          path: '/shopping',
          builder: (context, state) =>
              ShoppingPage(repo: repo, mealPlanRepo: mealPlanRepo),
        ),
        GoRoute(
          path: '/status',
          builder: (context, state) => StatusPage(mealPlanRepo: mealPlanRepo),
        ),
      ],
    ),
    GoRoute(
      path: '/details',
      builder: (context, state) {
        final recipe = state.extra as Recipe;
        return RecipeDetailsPage(
          recipe: recipe,
          repo: repo,
          mealPlanRepo: mealPlanRepo,
        );
      },
    ),
    GoRoute(
      path: '/new',
      builder: (context, state) => NewRecipePage(
        title: 'Neues Rezept',
        repo: repo,
        mealPlanRepo: mealPlanRepo,
      ),
    ),
    GoRoute(
      path: '/edit',
      builder: (context, state) {
        final recipe = state.extra as Recipe;
        return NewRecipePage(
          title: 'Rezept bearbeiten',
          repo: repo,
          mealPlanRepo: mealPlanRepo,
          initialRecipe: recipe,
        );
      },
    ),
  ],
);

RecipeRepository get recipeRepository => repo;
MealPlanRepository get mealPlanRepository => mealPlanRepo;
