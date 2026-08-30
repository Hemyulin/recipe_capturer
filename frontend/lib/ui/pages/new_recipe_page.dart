import 'dart:async';

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

class _PhotoCountBadge extends StatelessWidget {
  const _PhotoCountBadge({required this.count, required this.maxCount});

  final int count;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.photo_library_outlined,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              '$count/$maxCount',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IngredientEditorTile extends StatelessWidget {
  const _IngredientEditorTile({
    required this.row,
    required this.onRemove,
    this.nameHint = 'Zutat',
    this.onNameSubmitted,
  });

  final _IngredientRowData row;
  final VoidCallback onRemove;
  final String nameHint;
  final ValueChanged<String>? onNameSubmitted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: row.nameController,
                  focusNode: row.nameFocusNode,
                  decoration: InputDecoration(
                    labelText: 'Zutat',
                    hintText: nameHint,
                  ),
                  textInputAction: TextInputAction.next,
                  onSubmitted: onNameSubmitted,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Zutat entfernen',
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: row.quantityController,
                  decoration: const InputDecoration(
                    labelText: 'Menge',
                    hintText: '2',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: row.unitController,
                  decoration: const InputDecoration(
                    labelText: 'Einheit',
                    hintText: 'EL',
                  ),
                  textInputAction: TextInputAction.next,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: row.noteController,
            decoration: const InputDecoration(
              labelText: 'Notiz',
              hintText: 'optional, z.B. extra zum Servieren',
            ),
            textInputAction: TextInputAction.next,
          ),
        ],
      ),
    );
  }
}

class _AiImageProgressDialog extends StatelessWidget {
  const _AiImageProgressDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const SizedBox(
        width: 34,
        height: 34,
        child: CircularProgressIndicator(strokeWidth: 3),
      ),
      title: const Text('KI-Bild wird gekocht'),
      content: Text(
        'Das kann einen Moment dauern. Wenn alles klappt, liegt das neue Bild gleich vorne bei den Fotos.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _EditableImageThumb extends StatelessWidget {
  const _EditableImageThumb({
    required this.path,
    required this.isMain,
    required this.onMakeMain,
    required this.onRemove,
  });

  final String path;
  final bool isMain;
  final VoidCallback onMakeMain;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 96,
      child: Stack(
        children: [
          Positioned.fill(
            child: Material(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: isMain ? null : onMakeMain,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isMain
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                      width: isMain ? 2 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: RecipeImage(path: path, placeholderSeed: path),
                ),
              ),
            ),
          ),
          Positioned(
            right: 4,
            top: 4,
            child: IconButton.filledTonal(
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Foto entfernen',
              style: IconButton.styleFrom(
                minimumSize: const Size.square(28),
                fixedSize: const Size.square(28),
                padding: EdgeInsets.zero,
                backgroundColor: colorScheme.surface.withValues(alpha: 0.9),
              ),
            ),
          ),
          if (isMain)
            Positioned(
              left: 5,
              bottom: 5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  child: Text(
                    'Hauptbild',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
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
  final List<_StepRowData> _preparationTasks = [];
  final List<_StepRowData> _steps = [];
  final Set<String> _selectedTags = {};

  List<String> _imagePaths = [];
  int _imageRevision = 0;
  bool _isPolishing = false;
  bool _isGeneratingImage = false;

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
      for (final task in initialRecipe.preparationTasks) {
        _addPreparationTaskRow(text: task);
      }
      for (final step in initialRecipe.instructions) {
        _addStepRow(text: step);
      }
    }

    if (_ingredients.isEmpty) _addIngredientRow();
    if (_preparationTasks.isEmpty) _addPreparationTaskRow();
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
    for (final row in _preparationTasks) {
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

  void _addPreparationTaskRow({String text = ''}) {
    _preparationTasks.add(_StepRowData(text: text));
  }

  void _appendPreparationTaskAndFocus() {
    setState(_addPreparationTaskRow);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _preparationTasks.last.focusNode.requestFocus();
    });
  }

  void _removePreparationTaskRow(int index) {
    final row = _preparationTasks.removeAt(index);
    row.dispose();
    if (_preparationTasks.isEmpty) _addPreparationTaskRow();
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

  Future<void> _pickImages() async {
    final remainingSlots = 5 - _imagePaths.length;
    if (remainingSlots <= 0) return;

    final images = await ImagePicker().pickMultiImage(limit: remainingSlots);
    if (images.isEmpty) return;
    setState(() {
      _imagePaths = [
        ..._imagePaths,
        ...images.map((image) => image.path).take(remainingSlots),
      ];
      _imageRevision += 1;
    });
  }

  void _makeMainPhoto(int index) {
    if (index <= 0 || index >= _imagePaths.length) return;
    setState(() {
      final selected = _imagePaths.removeAt(index);
      _imagePaths.insert(0, selected);
      _imageRevision += 1;
    });
  }

  void _removePhoto(int index) {
    if (index < 0 || index >= _imagePaths.length) return;
    setState(() {
      _imagePaths.removeAt(index);
      _imageRevision += 1;
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

  List<String> _collectPreparationTasks() {
    return _preparationTasks
        .map((row) => row.controller.text.trim())
        .where((task) => task.isNotEmpty)
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
      preparationTasks: _collectPreparationTasks(),
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
      final reviewed = await _showPolishReview(draft, polished);
      if (reviewed != null) _replaceFormWithRecipe(reviewed);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_polishErrorMessage(error))));
    } finally {
      if (mounted) setState(() => _isPolishing = false);
    }
  }

  Future<Recipe?> _showPolishReview(Recipe original, Recipe suggestion) {
    return showDialog<Recipe>(
      context: context,
      builder: (context) => _RecipePolishReviewDialog(
        original: original,
        suggestion: suggestion,
        seasonOptions: _seasonOptions,
      ),
    );
  }

  Future<void> _generateRecipeImage() async {
    final imageRepo = widget.repo is RecipeAiImageRepository
        ? widget.repo as RecipeAiImageRepository
        : null;
    if (imageRepo == null || _isGeneratingImage || _imagePaths.length >= 5) {
      return;
    }

    late final Recipe draft;
    try {
      draft = _currentDraftRecipe();
    } catch (error) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_saveErrorMessage(error))));
      return;
    }

    setState(() => _isGeneratingImage = true);
    var progressDialogOpen = false;
    if (mounted) {
      progressDialogOpen = true;
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (context) => const _AiImageProgressDialog(),
        ),
      );
    }
    try {
      final imagePath = await imageRepo.generateRecipeImage(draft);
      if (!mounted) return;
      setState(() {
        _imagePaths = [imagePath, ..._imagePaths].take(5).toList();
        _imageRevision += 1;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('KI-Bild erstellt.')));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_imageErrorMessage(error))));
    } finally {
      if (mounted && progressDialogOpen) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) setState(() => _isGeneratingImage = false);
    }
  }

  void _replaceFormWithRecipe(Recipe recipe) {
    for (final row in _ingredients) {
      row.dispose();
    }
    for (final row in _preparationTasks) {
      row.dispose();
    }
    for (final row in _steps) {
      row.dispose();
    }
    _ingredients.clear();
    _preparationTasks.clear();
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
      for (final task in recipe.preparationTasks) {
        _addPreparationTaskRow(text: task);
      }
      for (final step in recipe.instructions) {
        _addStepRow(text: step);
      }
      if (_ingredients.isEmpty) _addIngredientRow();
      if (_preparationTasks.isEmpty) _addPreparationTaskRow();
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
      final recipeImagePaths = _imagePaths
          .where((path) => !_isLocalUploadCandidate(path))
          .toList();

      if (initialRecipe == null || widget.saveAsNew) {
        final recipe = Recipe.create(
          _titleController.text,
          ingredients: _collectIngredients(),
          instructions: _collectSteps(),
          preparationTasks: _collectPreparationTasks(),
          tags: _selectedTags.toList(),
          imagePaths: recipeImagePaths,
          servings: servings,
          season: _seasonController.text,
          prepTimeMinutes: prepTime,
          cookTimeMinutes: cookTime,
          notes: _notesController.text,
        );

        final savedRecipe = await widget.repo.add(recipe);
        var currentRecipe = savedRecipe;
        final uploadedPaths = <String, String>{};
        if (shouldUploadImages) {
          final uploader = imageRepository!;
          for (final imagePath in localUploadImages) {
            final uploadedRecipe = await uploader.uploadImage(
              recipeId: savedRecipe.id,
              imagePath: imagePath,
            );
            final newImagePath = uploadedRecipe.imagePaths
                .where((path) => !currentRecipe.imagePaths.contains(path))
                .lastOrNull;
            if (newImagePath != null) uploadedPaths[imagePath] = newImagePath;
            currentRecipe = uploadedRecipe;
          }
        }
        await _saveUploadedImageOrder(currentRecipe, uploadedPaths);
      } else {
        final updatedRecipe = initialRecipe.copyWith(
          title: _titleController.text.trim(),
          ingredients: _collectIngredients(),
          instructions: _collectSteps(),
          preparationTasks: _collectPreparationTasks(),
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
        var currentRecipe = savedRecipe;
        final uploadedPaths = <String, String>{};
        if (shouldUploadImages) {
          final uploader = imageRepository!;
          for (final imagePath in localUploadImages) {
            final uploadedRecipe = await uploader.uploadImage(
              recipeId: savedRecipe.id,
              imagePath: imagePath,
            );
            final newImagePath = uploadedRecipe.imagePaths
                .where((path) => !currentRecipe.imagePaths.contains(path))
                .lastOrNull;
            if (newImagePath != null) uploadedPaths[imagePath] = newImagePath;
            currentRecipe = uploadedRecipe;
          }
        }
        await _saveUploadedImageOrder(currentRecipe, uploadedPaths);
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

  Future<void> _saveUploadedImageOrder(
    Recipe currentRecipe,
    Map<String, String> uploadedPaths,
  ) async {
    if (uploadedPaths.isEmpty) return;
    final finalImagePaths = _imagePaths
        .map((path) => uploadedPaths[path] ?? path)
        .where((path) => !_isLocalUploadCandidate(path))
        .take(5)
        .toList();
    if (_sameStringList(finalImagePaths, currentRecipe.imagePaths)) return;
    await widget.repo.update(
      currentRecipe.copyWith(imagePaths: finalImagePaths),
    );
  }

  bool _sameStringList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var index = 0; index < a.length; index++) {
      if (a[index] != b[index]) return false;
    }
    return true;
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

  String _imageErrorMessage(Object error) {
    if (error is RecipeSaveException) return error.userMessage;
    return 'KI konnte kein Bild erstellen.';
  }

  Widget _buildPhotoPicker(ColorScheme colorScheme) {
    final imagePath = _imagePaths.isEmpty ? null : _imagePaths.first;
    final canAddImages = _imagePaths.length < 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: Material(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: canAddImages ? _pickImages : null,
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
                          'Fotos hinzufügen',
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
                          cacheKey: _imageRevision,
                        ),
                        Positioned(
                          left: 12,
                          bottom: 12,
                          child: _PhotoCountBadge(
                            count: _imagePaths.length,
                            maxCount: 5,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: Text(
                imagePath == null ? 'Keine Fotos' : 'Hauptbild zuerst',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            IconButton(
              onPressed: canAddImages ? _pickImages : null,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              tooltip: 'Foto hinzufügen',
            ),
            IconButton(
              onPressed:
                  canAddImages &&
                      !_isGeneratingImage &&
                      widget.repo is RecipeAiImageRepository
                  ? _generateRecipeImage
                  : null,
              icon: _isGeneratingImage
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_outlined),
              tooltip: 'KI-Bild generieren',
            ),
          ],
        ),
        if (_imagePaths.isNotEmpty) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _imagePaths.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return _EditableImageThumb(
                  path: _imagePaths[index],
                  isMain: index == 0,
                  onMakeMain: () => _makeMainPhoto(index),
                  onRemove: () => _removePhoto(index),
                );
              },
            ),
          ),
        ],
      ],
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
                  return _IngredientEditorTile(
                    row: row,
                    nameHint: index == _ingredients.length - 1
                        ? 'Zutat'
                        : 'Name',
                    onRemove: () => _removeIngredientRow(index),
                    onNameSubmitted: (_) => _appendIngredientAndFocus(),
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
            title: 'Vorbereitung',
            child: Column(
              children: [
                ...List.generate(_preparationTasks.length, (index) {
                  final row = _preparationTasks[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Icon(
                            Icons.hourglass_bottom_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: row.controller,
                            focusNode: row.focusNode,
                            minLines: 1,
                            maxLines: 3,
                            decoration: const InputDecoration(
                              hintText:
                                  'z.B. Linsen 3 Stunden einweichen lassen',
                            ),
                            textInputAction: TextInputAction.next,
                            onSubmitted: (_) =>
                                _appendPreparationTaskAndFocus(),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _removePreparationTaskRow(index),
                          icon: const Icon(Icons.delete_outline),
                          tooltip: 'Vorbereitung entfernen',
                        ),
                      ],
                    ),
                  );
                }),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _appendPreparationTaskAndFocus,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Vorbereitung'),
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

class _RecipePolishReviewDialog extends StatefulWidget {
  const _RecipePolishReviewDialog({
    required this.original,
    required this.suggestion,
    required this.seasonOptions,
  });

  final Recipe original;
  final Recipe suggestion;
  final List<String> seasonOptions;

  @override
  State<_RecipePolishReviewDialog> createState() =>
      _RecipePolishReviewDialogState();
}

class _RecipePolishReviewDialogState extends State<_RecipePolishReviewDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _servingsController;
  late final TextEditingController _prepTimeController;
  late final TextEditingController _cookTimeController;
  late final TextEditingController _notesController;
  late final TextEditingController _tagController;
  late String _season;
  final List<_IngredientRowData> _ingredients = [];
  final List<_StepRowData> _preparationTasks = [];
  final List<_StepRowData> _steps = [];
  final Set<String> _tags = {};

  @override
  void initState() {
    super.initState();
    _loadRecipe(widget.suggestion);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _servingsController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    _notesController.dispose();
    _tagController.dispose();
    for (final row in _ingredients) {
      row.dispose();
    }
    for (final row in _preparationTasks) {
      row.dispose();
    }
    for (final row in _steps) {
      row.dispose();
    }
    super.dispose();
  }

  void _loadRecipe(Recipe recipe) {
    _titleController = TextEditingController(text: recipe.title);
    _servingsController = TextEditingController(
      text: recipe.servings?.toString() ?? '',
    );
    _prepTimeController = TextEditingController(
      text: recipe.prepTimeMinutes?.toString() ?? '',
    );
    _cookTimeController = TextEditingController(
      text: recipe.cookTimeMinutes?.toString() ?? '',
    );
    _notesController = TextEditingController(text: recipe.notes);
    _tagController = TextEditingController();
    _season = widget.seasonOptions.contains(recipe.season)
        ? recipe.season
        : widget.seasonOptions.first;
    _replaceIngredients(recipe.ingredients);
    _replacePreparationTasks(recipe.preparationTasks);
    _replaceSteps(recipe.instructions);
    _tags
      ..clear()
      ..addAll(recipe.tags);
  }

  void _replaceIngredients(List<RecipeIngredient> ingredients) {
    for (final row in _ingredients) {
      row.dispose();
    }
    _ingredients
      ..clear()
      ..addAll(
        ingredients.map(
          (ingredient) => _IngredientRowData(
            quantity: ingredient.quantity,
            unit: ingredient.unit,
            name: ingredient.name,
            note: ingredient.note,
            excludeFromShopping: ingredient.excludeFromShopping,
          ),
        ),
      );
    if (_ingredients.isEmpty) _ingredients.add(_IngredientRowData());
  }

  void _replacePreparationTasks(List<String> tasks) {
    for (final row in _preparationTasks) {
      row.dispose();
    }
    _preparationTasks
      ..clear()
      ..addAll(tasks.map((task) => _StepRowData(text: task)));
    if (_preparationTasks.isEmpty) _preparationTasks.add(_StepRowData());
  }

  void _replaceSteps(List<String> steps) {
    for (final row in _steps) {
      row.dispose();
    }
    _steps
      ..clear()
      ..addAll(steps.map((step) => _StepRowData(text: step)));
    if (_steps.isEmpty) _steps.add(_StepRowData());
  }

  void _addIngredient() {
    setState(() => _ingredients.add(_IngredientRowData()));
  }

  void _removeIngredient(int index) {
    final row = _ingredients.removeAt(index);
    row.dispose();
    if (_ingredients.isEmpty) _ingredients.add(_IngredientRowData());
    setState(() {});
  }

  void _addPreparationTask() {
    setState(() => _preparationTasks.add(_StepRowData()));
  }

  void _removePreparationTask(int index) {
    final row = _preparationTasks.removeAt(index);
    row.dispose();
    if (_preparationTasks.isEmpty) _preparationTasks.add(_StepRowData());
    setState(() {});
  }

  void _addStep() {
    setState(() => _steps.add(_StepRowData()));
  }

  void _removeStep(int index) {
    final row = _steps.removeAt(index);
    row.dispose();
    if (_steps.isEmpty) _steps.add(_StepRowData());
    setState(() {});
  }

  void _addTag() {
    final value = _tagController.text.trim();
    if (value.isEmpty) return;
    setState(() {
      _tags.add(value);
      _tagController.clear();
    });
  }

  Recipe _reviewedRecipe() {
    return Recipe.create(
      _titleController.text,
      ingredients: _ingredients
          .map(
            (row) => RecipeIngredient(
              name: row.nameController.text.trim(),
              quantity: row.quantityController.text.trim(),
              unit: row.unitController.text.trim(),
              note: row.noteController.text.trim(),
              excludeFromShopping: row.excludeFromShopping,
            ),
          )
          .where((ingredient) => ingredient.name.isNotEmpty)
          .toList(),
      instructions: _steps
          .map((row) => row.controller.text.trim())
          .where((step) => step.isNotEmpty)
          .toList(),
      preparationTasks: _preparationTasks
          .map((row) => row.controller.text.trim())
          .where((task) => task.isNotEmpty)
          .toList(),
      tags: _tags.toList(),
      imagePaths: widget.original.imagePaths,
      servings: _positiveInt(_servingsController.text),
      season: _season,
      prepTimeMinutes: _positiveInt(_prepTimeController.text),
      cookTimeMinutes: _positiveInt(_cookTimeController.text),
      notes: _notesController.text,
    );
  }

  int? _positiveInt(String value) {
    final parsed = int.tryParse(value.trim());
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('KI-Vorschlag prüfen'),
            leading: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
              tooltip: 'Abbrechen',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(context).pop(_reviewedRecipe()),
                child: const Text('Übernehmen'),
              ),
              const SizedBox(width: 12),
            ],
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Bearbeiten'),
                Tab(text: 'Original'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  _ReviewSection(
                    title: 'Grundlagen',
                    originalChild: _buildOriginalBasics(),
                    child: _buildBasics(),
                  ),
                  const SizedBox(height: 12),
                  _ReviewSection(
                    title: 'Zutaten',
                    originalChild: _buildOriginalIngredients(),
                    child: _buildIngredients(),
                  ),
                  const SizedBox(height: 12),
                  _ReviewSection(
                    title: 'Zubereitung',
                    originalChild: _buildOriginalSteps(),
                    child: _buildSteps(),
                  ),
                  const SizedBox(height: 12),
                  _ReviewSection(
                    title: 'Vorbereitung',
                    originalChild: _buildOriginalPreparationTasks(),
                    child: _buildPreparationTasks(),
                  ),
                  const SizedBox(height: 12),
                  _ReviewSection(
                    title: 'Tags',
                    originalChild: _buildOriginalTags(),
                    child: _buildTags(),
                  ),
                  const SizedBox(height: 12),
                  _ReviewSection(
                    title: 'Notizen',
                    originalChild: _buildOriginalNotes(),
                    child: TextField(
                      controller: _notesController,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(hintText: 'Optional'),
                    ),
                  ),
                ],
              ),
              _OriginalRecipePreview(recipe: widget.original),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOriginalBasics() {
    final original = widget.original;
    return _OriginalValueList(
      values: [
        'Titel: ${original.title}',
        if (original.servings != null) 'Portionen: ${original.servings}',
        if (original.season.isNotEmpty) 'Saison: ${original.season}',
        if (original.prepTimeMinutes != null)
          'Vorbereitung: ${original.prepTimeMinutes} min',
        if (original.cookTimeMinutes != null)
          'Kochen: ${original.cookTimeMinutes} min',
      ],
      emptyText: 'Keine Grundlagen im Original.',
    );
  }

  Widget _buildOriginalIngredients() {
    return _OriginalValueList(
      values: widget.original.ingredients
          .map((ingredient) => ingredient.label)
          .toList(),
      emptyText: 'Keine Zutaten im Original.',
    );
  }

  Widget _buildOriginalSteps() {
    return _OriginalValueList(
      values: widget.original.instructions.indexed
          .map((entry) => '${entry.$1 + 1}. ${entry.$2}')
          .toList(),
      emptyText: 'Keine Schritte im Original.',
    );
  }

  Widget _buildOriginalPreparationTasks() {
    return _OriginalValueList(
      values: widget.original.preparationTasks,
      emptyText: 'Keine Vorbereitung im Original.',
    );
  }

  Widget _buildOriginalTags() {
    return _OriginalValueList(
      values: widget.original.tags.map(tagLabelDe).toList(),
      emptyText: 'Keine Tags im Original.',
    );
  }

  Widget _buildOriginalNotes() {
    return _OriginalValueList(
      values: widget.original.notes.trim().isEmpty
          ? const []
          : [widget.original.notes.trim()],
      emptyText: 'Keine Notizen im Original.',
    );
  }

  Widget _buildBasics() {
    return Column(
      children: [
        TextField(
          controller: _titleController,
          decoration: const InputDecoration(labelText: 'Titel'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _servingsController,
                decoration: const InputDecoration(labelText: 'Portionen'),
                keyboardType: TextInputType.number,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _season,
                decoration: const InputDecoration(labelText: 'Saison'),
                items: [
                  for (final season in widget.seasonOptions)
                    DropdownMenuItem(value: season, child: Text(season)),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _season = value);
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
                decoration: const InputDecoration(labelText: 'Vorbereitung'),
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
    );
  }

  Widget _buildIngredients() {
    return Column(
      children: [
        ...List.generate(_ingredients.length, (index) {
          final row = _ingredients[index];
          return _IngredientEditorTile(
            row: row,
            onRemove: () => _removeIngredient(index),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _addIngredient,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Zutat'),
          ),
        ),
      ],
    );
  }

  Widget _buildSteps() {
    return Column(
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
                  child: CircleAvatar(radius: 14, child: Text('${index + 1}')),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: row.controller,
                    minLines: 1,
                    maxLines: 5,
                    decoration: const InputDecoration(hintText: 'Schritt'),
                  ),
                ),
                IconButton(
                  onPressed: () => _removeStep(index),
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
            onPressed: _addStep,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Schritt'),
          ),
        ),
      ],
    );
  }

  Widget _buildPreparationTasks() {
    return Column(
      children: [
        ...List.generate(_preparationTasks.length, (index) {
          final row = _preparationTasks[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: Icon(
                    Icons.hourglass_bottom_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: row.controller,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'z.B. Teig über Nacht kühlen',
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _removePreparationTask(index),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Vorbereitung entfernen',
                ),
              ],
            ),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _addPreparationTask,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Vorbereitung'),
          ),
        ),
      ],
    );
  }

  Widget _buildTags() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...selectableRecipeTagLabelsDe.entries.map((entry) {
              final selected = _tags.contains(entry.key);
              return FilterChip(
                label: Text(entry.value),
                selected: selected,
                onSelected: (value) {
                  setState(() {
                    if (value) {
                      _tags.add(entry.key);
                    } else {
                      _tags.remove(entry.key);
                    }
                  });
                },
              );
            }),
            ..._tags
                .where((tag) => !selectableRecipeTagLabelsDe.containsKey(tag))
                .map(
                  (tag) => InputChip(
                    label: Text(tag),
                    selected: true,
                    onDeleted: () => setState(() => _tags.remove(tag)),
                  ),
                ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tagController,
                decoration: const InputDecoration(hintText: 'Eigener Tag'),
                onSubmitted: (_) => _addTag(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _addTag,
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Tag hinzufügen',
            ),
          ],
        ),
      ],
    );
  }
}

class _ReviewSection extends StatefulWidget {
  const _ReviewSection({
    required this.title,
    required this.child,
    required this.originalChild,
  });

  final String title;
  final Widget child;
  final Widget originalChild;

  @override
  State<_ReviewSection> createState() => _ReviewSectionState();
}

class _ReviewSectionState extends State<_ReviewSection> {
  bool _showOriginal = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: () =>
                      setState(() => _showOriginal = !_showOriginal),
                  icon: Icon(
                    _showOriginal
                        ? Icons.auto_fix_high_outlined
                        : Icons.history_rounded,
                  ),
                  label: Text(_showOriginal ? 'Vorschlag' : 'Original'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: KeyedSubtree(
                key: ValueKey(_showOriginal),
                child: _showOriginal ? widget.originalChild : widget.child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OriginalValueList extends StatelessWidget {
  const _OriginalValueList({required this.values, required this.emptyText});

  final List<String> values;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final cleanValues = values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    if (cleanValues.isEmpty) {
      return Text(
        emptyText,
        style: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...cleanValues.map(
          (value) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(value, style: textTheme.bodyMedium),
          ),
        ),
      ],
    );
  }
}

class _OriginalRecipePreview extends StatelessWidget {
  const _OriginalRecipePreview({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(recipe.title, style: textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          [
            if (recipe.servings != null) '${recipe.servings} Portionen',
            if (recipe.totalTimeMinutes != null)
              '${recipe.totalTimeMinutes} min',
            if (recipe.season.isNotEmpty) recipe.season,
          ].join(' · '),
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        Text('Zutaten', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        ...recipe.ingredients.map(
          (ingredient) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('• ${ingredient.label}'),
          ),
        ),
        if (recipe.preparationTasks.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Vorbereitung', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          ...recipe.preparationTasks.map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('• $task'),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Text('Zubereitung', style: textTheme.titleMedium),
        const SizedBox(height: 8),
        ...recipe.instructions.indexed.map(
          (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('${entry.$1 + 1}. ${entry.$2}'),
          ),
        ),
        if (recipe.tags.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Tags', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(recipe.tags.map(tagLabelDe).join(' · ')),
        ],
        if (recipe.notes.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Notizen', style: textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(recipe.notes),
        ],
      ],
    );
  }
}
