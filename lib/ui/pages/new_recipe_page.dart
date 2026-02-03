import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_capturer/data/recipe_repository.dart';
import 'package:recipe_capturer/domain/recipe.dart';

class NewRecipePage extends StatefulWidget {
  const NewRecipePage({super.key, required this.title, required this.repo});

  final String title;
  final RecipeRepository repo;

  @override
  State<NewRecipePage> createState() => _NewRecipePageState();
}

class _NewRecipePageState extends State<NewRecipePage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _ingredientsController = TextEditingController();

  final Set<String> _selectedTags = {};

  static const Map<String, String> _tagLabelsDe = {
    'quick': 'Schnell',
    'savory': 'Herzhaft',
    'dessert': 'Dessert',
    'sweet': 'Süß',
    'breakfast': 'Frühstück',
    'dinner': 'Abendessen',
    'snack': 'Snack',
    'vegetarian': 'Vegetarisch',
  };

  @override
  void dispose() {
    _titleController.dispose();
    _ingredientsController.dispose();
    super.dispose();
  }

  List<String> _parseIngredients(String raw) {
    return raw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  Future<void> _save() async {
    try {
      final recipe = Recipe.create(
        _titleController.text,
        ingredients: _parseIngredients(_ingredientsController.text),
        tags: _selectedTags.toList(),
      );

      await widget.repo.add(recipe);

      if (!context.mounted) return;
      context.pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rezepttitel kann nicht leer sein!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tagChips = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _tagLabelsDe.entries.map((e) {
        final key = e.key;
        final label = e.value;
        final selected = _selectedTags.contains(key);

        return FilterChip(
          label: Text(label),
          selected: selected,
          onSelected: (v) {
            setState(() {
              if (v) {
                _selectedTags.add(key);
              } else {
                _selectedTags.remove(key);
              }
            });
          },
        );
      }).toList(),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _save,
            tooltip: 'Speichern',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Titel'),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),

          const Text('Tags'),
          const SizedBox(height: 8),
          tagChips,

          const SizedBox(height: 16),
          TextField(
            controller: _ingredientsController,
            decoration: const InputDecoration(
              labelText: 'Zutaten (eine pro Zeile)',
              alignLabelWithHint: true,
            ),
            minLines: 6,
            maxLines: 12,
            keyboardType: TextInputType.multiline,
          ),
        ],
      ),
    );
  }
}
