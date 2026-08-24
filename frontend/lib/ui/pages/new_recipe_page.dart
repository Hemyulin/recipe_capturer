import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cookbuk/data/meal_plan_repository.dart';
import 'package:cookbuk/data/recipe_repository.dart';
import 'package:cookbuk/domain/recipe.dart';
import 'package:cookbuk/ui/formatters/tag_label_de.dart';
import 'package:cookbuk/ui/widgets/backend_connection_icon.dart';
import 'package:cookbuk/ui/widgets/recipe_image.dart';

class NewRecipePage extends StatefulWidget {
  const NewRecipePage({
    super.key,
    required this.title,
    required this.repo,
    this.mealPlanRepo,
    this.initialRecipe,
    this.saveAsNew = false,
  });

  final String title;
  final RecipeRepository repo;
  final MealPlanRepository? mealPlanRepo;
  final Recipe? initialRecipe;
  final bool saveAsNew;

  @override
  State<NewRecipePage> createState() => _NewRecipePageState();
}

class _IngredientRowData {
  _IngredientRowData({
    String quantity = '',
    String unit = '',
    String name = '',
    String note = '',
    this.excludeFromShopping = false,
  }) : quantityController = TextEditingController(text: quantity),
       unitController = TextEditingController(text: unit),
       nameController = TextEditingController(text: name),
       noteController = TextEditingController(text: note),
       nameFocusNode = FocusNode();

  final TextEditingController quantityController;
  final TextEditingController unitController;
  final TextEditingController nameController;
  final TextEditingController noteController;
  final FocusNode nameFocusNode;
  final bool excludeFromShopping;

  void dispose() {
    quantityController.dispose();
    unitController.dispose();
    nameController.dispose();
    noteController.dispose();
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
  static const _seasonOptions = [
    'Ganzjährig',
    'Frühling',
    'Sommer',
    'Herbst',
    'Winter',
  ];

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
  bool _isPolishing = false;

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
          note: ingredient.note,
          excludeFromShopping: ingredient.excludeFromShopping,
        );
      }
      for (final step in initialRecipe.instructions) {
        _addStepRow(text: step);
      }
    }

    if (_ingredients.isEmpty) _addIngredientRow();
    if (_steps.isEmpty) _addStepRow();
    if (!_seasonOptions.contains(_seasonController.text.trim())) {
      _seasonController.text = _seasonOptions.first;
    }
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
    String note = '',
    bool excludeFromShopping = false,
  }) {
    _ingredients.add(
      _IngredientRowData(
        quantity: quantity,
        unit: unit,
        name: name,
        note: note,
        excludeFromShopping: excludeFromShopping,
      ),
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

  bool _isLocalUploadCandidate(String? path) {
    if (path == null || path.isEmpty) return false;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return false;
    }
    if (path.startsWith('assets/') || path.startsWith('/images/')) {
      return false;
    }
    return true;
  }

  List<RecipeIngredient> _collectIngredients() {
    return _ingredients
        .map(
          (row) => RecipeIngredient(
            name: row.nameController.text.trim(),
            quantity: row.quantityController.text.trim(),
            unit: row.unitController.text.trim(),
            note: row.noteController.text.trim(),
            excludeFromShopping:
                row.excludeFromShopping ||
                _isHouseholdBasic(row.nameController.text),
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

  Recipe _currentDraftRecipe() {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      throw ArgumentError('Recipe title cannot be empty');
    }
    return Recipe.create(
      title,
      ingredients: _collectIngredients(),
      instructions: _collectSteps(),
      tags: _selectedTags.toList(),
      imagePaths: _imagePaths,
      servings: _parsePositiveInt(_servingsController),
      season: _seasonController.text,
      prepTimeMinutes: _parsePositiveInt(_prepTimeController),
      cookTimeMinutes: _parsePositiveInt(_cookTimeController),
      notes: _notesController.text,
    );
  }

  Future<void> _polishRecipe() async {
    final polishRepo = widget.repo is RecipeAiPolishRepository
        ? widget.repo as RecipeAiPolishRepository
        : null;
    if (polishRepo == null || _isPolishing) return;

    late final Recipe draft;
    try {
      draft = _currentDraftRecipe();
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_saveErrorMessage(error))));
      return;
    }

    setState(() => _isPolishing = true);
    try {
      final polished = await polishRepo.polishRecipe(draft);
      if (!mounted) return;
      final shouldApply = await _showPolishPreview(polished);
      if (shouldApply == true) _replaceFormWithRecipe(polished);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_polishErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _isPolishing = false);
    }
  }

  Future<bool?> _showPolishPreview(Recipe recipe) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('KI-Vorschlag übernehmen?'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  recipe.title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 10),
                if (recipe.ingredients.isNotEmpty) ...[
                  Text(
                    'Zutaten',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recipe.ingredients
                        .take(6)
                        .map((ingredient) => '• ${ingredient.label}')
                        .join('\n'),
                  ),
                  if (recipe.ingredients.length > 6)
                    Text('… ${recipe.ingredients.length - 6} weitere'),
                  const SizedBox(height: 12),
                ],
                if (recipe.instructions.isNotEmpty) ...[
                  Text(
                    'Zubereitung',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recipe.instructions
                        .take(4)
                        .indexed
                        .map((entry) => '${entry.$1 + 1}. ${entry.$2}')
                        .join('\n'),
                  ),
                  if (recipe.instructions.length > 4)
                    Text('… ${recipe.instructions.length - 4} weitere'),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => context.pop(true),
            child: const Text('Übernehmen'),
          ),
        ],
      ),
    );
  }

  void _replaceFormWithRecipe(Recipe recipe) {
    for (final row in _ingredients) {
      row.dispose();
    }
    for (final row in _steps) {
      row.dispose();
    }
    _ingredients.clear();
    _steps.clear();

    setState(() {
      _titleController.text = recipe.title;
      _servingsController.text = recipe.servings?.toString() ?? '';
      _prepTimeController.text = recipe.prepTimeMinutes?.toString() ?? '';
      _cookTimeController.text = recipe.cookTimeMinutes?.toString() ?? '';
      _seasonController.text = _seasonOptions.contains(recipe.season)
          ? recipe.season
          : _seasonOptions.first;
      _notesController.text = recipe.notes;
      _selectedTags
        ..clear()
        ..addAll(recipe.tags);

      for (final ingredient in recipe.ingredients) {
        _addIngredientRow(
          quantity: ingredient.quantity,
          unit: ingredient.unit,
          name: ingredient.name,
          note: ingredient.note,
          excludeFromShopping: ingredient.excludeFromShopping,
        );
      }
      for (final step in recipe.instructions) {
        _addStepRow(text: step);
      }
      if (_ingredients.isEmpty) _addIngredientRow();
      if (_steps.isEmpty) _addStepRow();
    });
  }

  int? _parsePositiveInt(TextEditingController controller) {
    final value = int.tryParse(controller.text.trim());
    if (value == null || value <= 0) return null;
    return value;
  }

  bool _isHouseholdBasic(String name) {
    final normalized = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
        .trim();
    return const {
      'water',
      'boiling water',
      'tap water',
      'cold water',
      'hot water',
      'ice',
      'wasser',
      'kochendes wasser',
      'leitungswasser',
      'kaltes wasser',
      'heisses wasser',
      'heißes wasser',
      'eis',
    }.contains(normalized);
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
      final imageRepository = widget.repo is RecipeImageRepository
          ? widget.repo as RecipeImageRepository
          : null;
      final localUploadImages = imageRepository == null
          ? const <String>[]
          : _imagePaths.where(_isLocalUploadCandidate).take(5).toList();
      final shouldUploadImages = localUploadImages.isNotEmpty;
      final recipeImagePaths = shouldUploadImages
          ? widget.saveAsNew
                ? _imagePaths
                      .where((path) => !_isLocalUploadCandidate(path))
                      .toList()
                : initialRecipe?.imagePaths ?? const <String>[]
          : _imagePaths;

      if (initialRecipe == null || widget.saveAsNew) {
        final recipe = Recipe.create(
          _titleController.text,
          ingredients: _collectIngredients(),
          instructions: _collectSteps(),
          tags: _selectedTags.toList(),
          imagePaths: recipeImagePaths,
          servings: servings,
          season: _seasonController.text,
          prepTimeMinutes: prepTime,
          cookTimeMinutes: cookTime,
          notes: _notesController.text,
        );

        final savedRecipe = await widget.repo.add(recipe);
        if (shouldUploadImages) {
          final uploader = imageRepository!;
          for (final imagePath in localUploadImages) {
            await uploader.uploadImage(
              recipeId: savedRecipe.id,
              imagePath: imagePath,
            );
          }
        }
      } else {
        final updatedRecipe = initialRecipe.copyWith(
          title: _titleController.text.trim(),
          ingredients: _collectIngredients(),
          instructions: _collectSteps(),
          tags: _selectedTags.toList(),
          imagePaths: recipeImagePaths,
          servings: servings,
          clearServings: servings == null,
          season: _seasonController.text.trim(),
          prepTimeMinutes: prepTime,
          clearPrepTime: prepTime == null,
          cookTimeMinutes: cookTime,
          clearCookTime: cookTime == null,
          notes: _notesController.text.trim(),
        );

        final savedRecipe = await widget.repo.update(updatedRecipe);
        if (shouldUploadImages) {
          final uploader = imageRepository!;
          for (final imagePath in localUploadImages) {
            await uploader.uploadImage(
              recipeId: savedRecipe.id,
              imagePath: imagePath,
            );
          }
        }
      }

      if (!mounted) return;
      context.pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_saveErrorMessage(error))));
    }
  }

  String _saveErrorMessage(Object error) {
    if (error is RecipeSaveException) return error.userMessage;
    if (error is ArgumentError) return 'Rezepttitel kann nicht leer sein!';
    return 'Rezept konnte nicht gespeichert werden.';
  }

  String _polishErrorMessage(Object error) {
    if (error is RecipeSaveException) return error.userMessage;
    return 'KI konnte das Rezept nicht aufräumen.';
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
                    RecipeImage(
                      path: imagePath,
                      placeholderSeed: widget.initialRecipe?.id,
                    ),
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
        ...selectableRecipeTagLabelsDe.entries.map((e) {
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
            .where((tag) => !selectableRecipeTagLabelsDe.containsKey(tag))
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
          if (widget.mealPlanRepo != null)
            BackendConnectionIcon(mealPlanRepo: widget.mealPlanRepo!),
          IconButton(
            icon: _isPolishing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.auto_fix_high_outlined),
            onPressed: _isPolishing ? null : _polishRecipe,
            tooltip: 'Mit KI aufräumen',
          ),
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
                      child: DropdownButtonFormField<String>(
                        initialValue:
                            _seasonOptions.contains(_seasonController.text)
                            ? _seasonController.text
                            : _seasonOptions.first,
                        decoration: const InputDecoration(labelText: 'Saison'),
                        items: [
                          for (final season in _seasonOptions)
                            DropdownMenuItem(
                              value: season,
                              child: Text(season),
                            ),
                        ],
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _seasonController.text = value);
                        },
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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 70,
                              child: TextField(
                                controller: row.quantityController,
                                decoration: const InputDecoration(
                                  hintText: '2',
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 72,
                              child: TextField(
                                controller: row.unitController,
                                decoration: const InputDecoration(
                                  hintText: 'EL',
                                ),
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
                        Padding(
                          padding: const EdgeInsets.only(left: 150, right: 48),
                          child: TextField(
                            controller: row.noteController,
                            decoration: const InputDecoration(
                              hintText: 'Notiz, z.B. extra zum Servieren',
                            ),
                            textInputAction: TextInputAction.next,
                          ),
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
