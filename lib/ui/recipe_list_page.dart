import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_capturer/data/recipe_repository.dart';
import 'package:recipe_capturer/domain/recipe.dart';
import 'package:recipe_capturer/ui/recipe_card.dart';

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

  Future<void> _refresh() async {
    final snapshot = await widget.repo.getAll();
    if (!mounted) return;
    setState(() => recipesSnapshot = snapshot);
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = recipesSnapshot.isEmpty
        ? Center(child: const Text('Keine Rezepte vorhanden'))
        : ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: recipesSnapshot.length,
            itemBuilder: (context, index) {
              final recipe = recipesSnapshot[index];
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: RecipeCard(
                  recipe: recipe,
                  onDelete: () async {
                    await widget.repo.deleteById(recipe.id);
                    await _refresh();
                  },
                ),
              );
            },
          );

    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final saved = await context.push<bool>('/new');
          if (saved == true) await _refresh();
        },
        child: const Icon(Icons.add),
      ),
      body: content,
    );
  }
}
