import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_capturer/domain/recipe.dart';

class NewRecipePage extends StatefulWidget {
  const NewRecipePage({super.key, required this.title});

  final String title;

  @override
  State<NewRecipePage> createState() => _NewRecipePageState();
}

class _NewRecipePageState extends State<NewRecipePage> {
  final TextEditingController _titleController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: () {
              try {
                final raw = _titleController.text;
                debugPrint('RAW TITLE: "$raw" (len=${raw.length})');
                final recipe = Recipe.create(_titleController.text);
                context.pop(recipe);
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Rezepttitel kann nicht leer sein!'),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: _titleController,
          decoration: const InputDecoration(labelText: 'Titel'),
        ),
      ),
    );
  }
}
