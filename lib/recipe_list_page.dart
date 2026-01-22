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
  List<Recipe> recipes = [];

  @override
  Widget build(BuildContext context) {
    final Widget content = recipes.isEmpty
        ? Text('Keine Rezepte vorhanden')
        : ListView(
            children: recipes
                .map((recipe) => Card(child: Text(recipe.title)))
                .toList(),
          );

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final recipe = await context.push<Recipe>('/new');
          if (recipe == null) return;
          setState(() => recipes.add(recipe));
        },
        child: const Icon(Icons.add),
      ),
      body: Center(child: content),
    );
  }
}
