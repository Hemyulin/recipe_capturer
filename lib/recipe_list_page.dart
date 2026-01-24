import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_capturer/data/recipe_repository.dart';
import 'package:recipe_capturer/domain/recipe.dart';

class RecipeListPage extends StatefulWidget {
  const RecipeListPage({super.key, required this.title, required this.repo});

  final String title;
  final RecipeRepository repo;

  @override
  State<RecipeListPage> createState() => _RecipeListPageState();
}

class _RecipeListPageState extends State<RecipeListPage> {
  List<Recipe> recipesSnapshot = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() => recipesSnapshot = widget.repo.getAll());
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = recipesSnapshot.isEmpty
        ? const Text('Keine Rezepte vorhanden')
        : ListView(
            children: recipesSnapshot.map((recipe) => Card(child: Text(recipe.title))).toList(),
          );

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final saved = await context.push<bool>('/new');
          if (saved == true) _refresh();
        },
        child: const Icon(Icons.add),
      ),
      body: Center(child: content),
    );
  }
}
