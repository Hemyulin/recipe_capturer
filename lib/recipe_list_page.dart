import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_capturer/domain/recipe.dart';

class RecipeListPage extends StatefulWidget {
  const RecipeListPage({super.key, required this.title});

  final String title;

  @override
  State<RecipeListPage> createState() => _RecipeListPageState();
}

class _RecipeListPageState extends State<RecipeListPage> {
  Recipe? lastRecipe;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final recipe = await context.push<Recipe>('/new');
          if (recipe == null) return;
          setState(() => lastRecipe = recipe);
        },
        child: const Icon(Icons.add),
      ),
      body: Center(
        child: Text(
          lastRecipe == null
              ? 'Keine Rezepte vorhanden'
              : 'Letzes Rezept: ${lastRecipe!.title}',
        ),
      ),
    );
  }
}
