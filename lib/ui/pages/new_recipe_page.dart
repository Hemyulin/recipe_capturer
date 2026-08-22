import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:recipe_capturer/data/recipe_repository.dart';
import 'package:recipe_capturer/domain/recipe.dart';
import 'package:recipe_capturer/ui/widgets/recipe_image.dart';

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

class _IngredientRowData {
  _IngredientRowData({String quantity = '', String unit = '', String name = ''})
    : quantityController = TextEditingController(text: quantity),
      unitController = TextEditingController(text: unit),
      nameController = TextEditingController(text: name),
      nameFocusNode = FocusNode();

  final TextEditingController quantityController;
  final TextEditingController unitController;
  final TextEditingController nameController;
  final FocusNode nameFocusNode;

  void dispose() {
    quantityController.dispose();
    unitController.dispose();
    nameController.dispose();
    nameFocusNode.dispose();
  }
}

class _StepRowData {
  _StepRowData({String text = ''})
    : controller = TextEditingController(text: text),
      focusNode = FocusNode();

  final TextEditingController controller;
  final FocusNode focusNode;

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

class _NewRecipePageState extends State<NewRecipePage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _servingsController = TextEditingController();
  final TextEditingController _prepTimeController = TextEditingController();
  final TextEditingController _cookTimeController = TextEditingController();
  final TextEditingController _seasonController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();

  final List<_IngredientRowData> _ingredients = [];
  final List<_StepRowData> _steps = [];
  final Set<String> _selectedTags = {};

  List<String> _imagePaths = [];

  static const Map<String, String> _tagLabelsDe = {
    'quick': 'Schnell',
    'savory': 'Herzhaft',
    'dessert': 'Dessert',
    'sweet': 'Süß',
    'breakfast': 'Frühstück',
    'lunch': 'Mittagessen',
    'dinner': 'Abendessen',
    'one_pot': 'One pot',
    'snack': 'Snack',
    'vegetarian': 'Vegetarisch',
  };

  @override
  void initState() {
    super.initState();

    final initialRecipe = widget.initialRecipe;
    if (initialRecipe != null) {
      _titleController.text = initialRecipe.title;
      _servingsController.text = initialRecipe.servings?.toString() ?? '';
      _prepTimeController.text =
          initialRecipe.prepTimeMinutes?.toString() ?? '';
      _cookTimeController.text =
          initialRecipe.cookTimeMinutes?.toString() ?? '';
      _seasonController.text = initialRecipe.season;
      _notesController.text = initialRecipe.notes;
      _selectedTags.addAll(initialRecipe.tags);
      _imagePaths = [...initialRecipe.imagePaths];

      for (final ingredient in initialRecipe.ingredients) {
        _addIngredientRow(
          quantity: ingredient.quantity,
          unit: ingredient.unit,
          name: ingredient.name,
        );
      }
      for (final step in initialRecipe.instructions) {
        _addStepRow(text: step);
      }
    }

    if (_ingredients.isEmpty) _addIngredientRow();
    if (_steps.isEmpty) _addStepRow();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _servingsController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    _seasonController.dispose();
    _notesController.dispose();
    _tagController.dispose();
    for (final row in _ingredients) {
      row.dispose();
    }
    for (final row in _steps) {
      row.dispose();
    }
    super.dispose();
  }

  void _addIngredientRow({
    String quantity = '',
    String unit = '',
    String name = '',
  }) {
    _ingredients.add(
      _IngredientRowData(quantity: quantity, unit: unit, name: name),
    );
  }

  void _appendIngredientAndFocus() {
    setState(_addIngredientRow);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ingredients.last.nameFocusNode.requestFocus();
    });
  }

  void _removeIngredientRow(int index) {
    final row = _ingredients.removeAt(index);
    row.dispose();
    if (_ingredients.isEmpty) _addIngredientRow();
    setState(() {});
  }

  void _addStepRow({String text = ''}) {
    _steps.add(_StepRowData(text: text));
  }

  void _appendStepAndFocus() {
    setState(_addStepRow);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _steps.last.focusNode.requestFocus();
    });
  }

  void _removeStepRow(int index) {
    final row = _steps.removeAt(index);
    row.dispose();
    if (_steps.isEmpty) _addStepRow();
    setState(() {});
  }

  Future<void> _pickMainPhoto() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return;
    setState(() {
      _imagePaths = [image.path, ..._imagePaths.skip(1)];
    });
  }

  List<RecipeIngredient> _collectIngredients() {
    return _ingredients
        .map(
          (row) => RecipeIngredient(
            name: row.nameController.text.trim(),
            quantity: row.quantityController.text.trim(),
            unit: row.unitController.text.trim(),
          ),
        )
        .where((ingredient) => ingredient.name.isNotEmpty)
        .toList();
  }

  List<String> _collectSteps() {
    return _steps
        .map((row) => row.controller.text.trim())
        .where((step) => step.isNotEmpty)
        .toList();
  }

  int? _parsePositiveInt(TextEditingController controller) {
    final value = int.tryParse(controller.text.trim());
    if (value == null || value <= 0) return null;
    return value;
  }

  void _addCustomTag() {
    final value = _tagController.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _selectedTags.add(value);
      _tagController.clear();
    });
  }

  Future<void> _save() async {
    try {
      final initialRecipe = widget.initialRecipe;
      final servings = _parsePositiveInt(_servingsController);
      final prepTime = _parsePositiveInt(_prepTimeController);
      final cookTime = _parsePositiveInt(_cookTimeController);

      if (initialRecipe == null) {
        final recipe = Recipe.create(
          _titleController.text,
          ingredients: _collectIngredients(),
          instructions: _collectSteps(),
          tags: _selectedTags.toList(),
          imagePaths: _imagePaths,
          servings: servings,
          season: _seasonController.text,
          prepTimeMinutes: prepTime,
          cookTimeMinutes: cookTime,
          notes: _notesController.text,
        );

        await widget.repo.add(recipe);
      } else {
        final updatedRecipe = initialRecipe.copyWith(
          title: _titleController.text.trim(),
          ingredients: _collectIngredients(),
          instructions: _collectSteps(),
          tags: _selectedTags.toList(),
          imagePaths: _imagePaths,
          servings: servings,
          clearServings: servings == null,
          season: _seasonController.text.trim(),
          prepTimeMinutes: prepTime,
          clearPrepTime: prepTime == null,
          cookTimeMinutes: cookTime,
          clearCookTime: cookTime == null,
          notes: _notesController.text.trim(),
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

  Widget _buildPhotoPicker(ColorScheme colorScheme) {
    final imagePath = _imagePaths.isEmpty ? null : _imagePaths.first;

    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Material(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _pickMainPhoto,
          child: imagePath == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      size: 36,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Hauptfoto hinzufügen',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                )
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    RecipeImage(path: imagePath),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: FilledButton.icon(
                        onPressed: _pickMainPhoto,
                        icon: const Icon(Icons.photo_camera_outlined),
                        label: const Text('Ändern'),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final tagChips = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ..._tagLabelsDe.entries.map((e) {
          final selected = _selectedTags.contains(e.key);
          return FilterChip(
            label: Text(e.value),
            selected: selected,
            onSelected: (value) {
              setState(() {
                if (value) {
                  _selectedTags.add(e.key);
                } else {
                  _selectedTags.remove(e.key);
                }
              });
            },
          );
        }),
        ..._selectedTags
            .where((tag) => !_tagLabelsDe.containsKey(tag))
            .map(
              (tag) => InputChip(
                label: Text(tag),
                selected: true,
                onDeleted: () => setState(() => _selectedTags.remove(tag)),
              ),
            ),
      ],
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: _save,
            tooltip: 'Speichern',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _buildPhotoPicker(colorScheme),
          const SizedBox(height: 16),
          _buildSection(
            title: 'Grundlagen',
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Titel'),
                  textInputAction: TextInputAction.next,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _servingsController,
                        decoration: const InputDecoration(
                          labelText: 'Portionen',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _seasonController,
                        decoration: const InputDecoration(labelText: 'Saison'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _prepTimeController,
                        decoration: const InputDecoration(
                          labelText: 'Vorbereitung',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _cookTimeController,
                        decoration: const InputDecoration(labelText: 'Kochen'),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildSection(
            title: 'Zutaten',
            child: Column(
              children: [
                ...List.generate(_ingredients.length, (index) {
                  final row = _ingredients[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 70,
                          child: TextField(
                            controller: row.quantityController,
                            decoration: const InputDecoration(hintText: '2'),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 72,
                          child: TextField(
                            controller: row.unitController,
                            decoration: const InputDecoration(hintText: 'EL'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: row.nameController,
                            focusNode: row.nameFocusNode,
                            decoration: InputDecoration(
                              hintText: index == _ingredients.length - 1
                                  ? 'Zutat'
                                  : 'Name',
                            ),
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) => _appendIngredientAndFocus(),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _removeIngredientRow(index),
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Zutat entfernen',
                        ),
                      ],
                    ),
                  );
                }),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _appendIngredientAndFocus,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Zutat'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildSection(
            title: 'Zubereitung',
            child: Column(
              children: [
                ...List.generate(_steps.length, (index) {
                  final row = _steps[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: CircleAvatar(
                            radius: 14,
                            child: Text('${index + 1}'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: row.controller,
                            focusNode: row.focusNode,
                            minLines: 1,
                            maxLines: 4,
                            decoration: const InputDecoration(
                              hintText: 'Schritt',
                            ),
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) => _appendStepAndFocus(),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _removeStepRow(index),
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Schritt entfernen',
                        ),
                      ],
                    ),
                  );
                }),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _appendStepAndFocus,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Schritt'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildSection(
            title: 'Tags',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                tagChips,
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _tagController,
                        decoration: const InputDecoration(
                          hintText: 'Eigener Tag',
                        ),
                        onSubmitted: (_) => _addCustomTag(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: _addCustomTag,
                      icon: const Icon(Icons.add_rounded),
                      tooltip: 'Tag hinzufügen',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildSection(
            title: 'Notizen',
            child: TextField(
              controller: _notesController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(hintText: 'Optional'),
            ),
          ),
        ],
      ),
    );
  }
}
