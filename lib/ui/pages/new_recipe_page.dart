import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_capturer/data/recipe_repository.dart';
import 'package:recipe_capturer/domain/recipe.dart';

class NewRecipePage extends StatefulWidget {
  const NewRecipePage({
    super.key,
    required this.title,
    required this.repo,
    this.initialRecipe,
  });

  final String title;
  final RecipeRepository repo;
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

  List<String> _imagePaths = [];

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
      _imagePaths = [...initialRecipe.imagePaths];

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

    _addIngredientRow();
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

  void _openImageViewer(int initialIndex) {
    if (_imagePaths.isEmpty) return;

    showDialog<void>(
      context: context,
      builder: (_) => _RecipeImageViewerDialog(
        imagePaths: _imagePaths,
        initialIndex: initialIndex,
      ),
    );
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
          imagePaths: _imagePaths,
        );

        await widget.repo.add(recipe);
      } else {
        final updatedRecipe = initialRecipe.copyWith(
          title: _titleController.text.trim(),
          ingredients: _collectIngredients(),
          tags: _selectedTags.toList(),
          instructions: _instructionsController.text.trim(),
          imagePaths: _imagePaths,
        );

        await widget.repo.update(updatedRecipe);
      }

      if (!mounted) return;
      context.pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rezepttitel kann nicht leer sein!')),
      );
    }
  }

  Widget _buildImagePreviewSection() {
    if (_imagePaths.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Bilder',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _imagePaths.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final path = _imagePaths[index];

                  return GestureDetector(
                    onTap: () => _openImageViewer(index),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Image.file(
                          File(path),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: Colors.black12,
                            child: Center(
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Titel'),
                    textInputAction: TextInputAction.next,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildImagePreviewSection(),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tags',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  tagChips,
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Zutaten',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
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
                              onSubmitted: (_) =>
                                  _handleIngredientSubmitted(index),
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: isLast
                                    ? 'Zutat eingeben und Enter drücken'
                                    : 'Zutat ${index + 1}',
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Zubereitung',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _instructionsController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Zubereitung eingeben',
                      alignLabelWithHint: true,
                    ),
                    minLines: 6,
                    maxLines: 12,
                    keyboardType: TextInputType.multiline,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _RecipeImageViewerDialog extends StatefulWidget {
  const _RecipeImageViewerDialog({
    required this.imagePaths,
    required this.initialIndex,
  });

  final List<String> imagePaths;
  final int initialIndex;

  @override
  State<_RecipeImageViewerDialog> createState() =>
      _RecipeImageViewerDialogState();
}

class _RecipeImageViewerDialogState extends State<_RecipeImageViewerDialog> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text('${_currentIndex + 1}/${widget.imagePaths.length}'),
        ),
        body: PageView.builder(
          controller: _pageController,
          itemCount: widget.imagePaths.length,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          itemBuilder: (context, index) {
            final path = widget.imagePaths[index];
            return InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Image.file(
                  File(path),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.broken_image_outlined,
                    size: 44,
                    color: Colors.white70,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
