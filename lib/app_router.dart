import 'package:go_router/go_router.dart';
import 'package:recipe_capturer/recipe_list_page.dart';

final router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => RecipeListPage(title: 'Recipes'),
    ),
  ],
);
