import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_capturer/data/recipe_repository.dart';
import 'package:recipe_capturer/domain/recipe.dart';

class NewRecipePage extends StatefulWidget {
  const NewRecipePage({
    super.key,
    required this.title,
    required this.repo,
    this.initialTitle,
    this.initialIngredients,
    this.initialInstructions,
    this.initialRecipe,
  });

  final String title;
  final RecipeRepository repo;
  final String? initialTitle;
  final String? initialIngredients;
  final String? initialInstructions;
  final Recipe? initialRecipe;

  @override
  State<NewRecipePage> createState() => _NewRecipePageState();
}

class _NewRecipePageState extends State<NewRecipePage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();
  final Set<String> _selectedTags = {};

  final List<TextEditingController> _ingredientControllers = [];
  final List<FocusNode> _ingredientFocusNodes = [];

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
  void initState() {
    super.initState();

    final initialRecipe = widget.initialRecipe;

    if (initialRecipe != null) {
      _titleController.text = initialRecipe.title;
      _instructionsController.text = initialRecipe.instructions;
      _selectedTags.addAll(initialRecipe.tags);

      if (initialRecipe.ingredients.isEmpty) {
        _addIngredientRow();
      } else {
        for (final ingredient in initialRecipe.ingredients) {
          _addIngredientRow(text: ingredient);
        }
        _addIngredientRow();
      }

      return;
    }

    if (widget.initialTitle != null) {
      _titleController.text = widget.initialTitle!;
    }

    if (widget.initialInstructions != null) {
      _instructionsController.text = widget.initialInstructions!;
    }

    final initialLines = (widget.initialIngredients ?? '')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (initialLines.isEmpty) {
      _addIngredientRow();
    } else {
      for (final line in initialLines) {
        _addIngredientRow(text: line);
      }
      _addIngredientRow();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _instructionsController.dispose();

    for (final controller in _ingredientControllers) {
      controller.dispose();
    }
    for (final focusNode in _ingredientFocusNodes) {
      focusNode.dispose();
    }

    super.dispose();
  }

  void _addIngredientRow({String text = ''}) {
    _ingredientControllers.add(TextEditingController(text: text));
    _ingredientFocusNodes.add(FocusNode());
  }

  void _appendRowAndFocus() {
    setState(() {
      _addIngredientRow();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ingredientFocusNodes.last.requestFocus();
    });
  }

  void _handleIngredientSubmitted(int index) {
    final currentText = _ingredientControllers[index].text.trim();
    final isLastRow = index == _ingredientControllers.length - 1;

    if (currentText.isEmpty) return;

    if (isLastRow) {
      _appendRowAndFocus();
      return;
    }

    _ingredientFocusNodes[index + 1].requestFocus();
  }

  void _removeIngredientRow(int index) {
    final controller = _ingredientControllers.removeAt(index);
    final focusNode = _ingredientFocusNodes.removeAt(index);

    controller.dispose();
    focusNode.dispose();

    if (_ingredientControllers.isEmpty) {
      _addIngredientRow();
    }

    setState(() {});
  }

  List<String> _collectIngredients() {
    return _ingredientControllers
        .map((controller) => controller.text.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  Future<void> _save() async {
    try {
      final initialRecipe = widget.initialRecipe;

      if (initialRecipe == null) {
        final recipe = Recipe.create(
          _titleController.text,
          ingredients: _collectIngredients(),
          tags: _selectedTags.toList(),
          instructions: _instructionsController.text,
        );

        await widget.repo.add(recipe);
      } else {
        final updatedRecipe = initialRecipe.copyWith(
          title: _titleController.text.trim(),
          ingredients: _collectIngredients(),
          tags: _selectedTags.toList(),
          instructions: _instructionsController.text.trim(),
        );

        await widget.repo.update(updatedRecipe);
      }

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
            decoration: const InputDecoration(
              labelText: 'Titel',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          const Text('Tags'),
          const SizedBox(height: 8),
          tagChips,
          const SizedBox(height: 20),
          const Text(
            'Zutaten',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...List.generate(_ingredientControllers.length, (index) {
            final isLast = index == _ingredientControllers.length - 1;

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ingredientControllers[index],
                      focusNode: _ingredientFocusNodes[index],
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) => _handleIngredientSubmitted(index),
                      decoration: InputDecoration(
                        hintText: isLast
                            ? 'Zutat eingeben und Enter drücken'
                            : 'Zutat ${index + 1}',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _removeIngredientRow(index),
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Zutat entfernen',
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 20),
          const Text(
            'Zubereitung',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _instructionsController,
            decoration: const InputDecoration(
              hintText: 'Zubereitung eingeben',
              border: OutlineInputBorder(),
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
