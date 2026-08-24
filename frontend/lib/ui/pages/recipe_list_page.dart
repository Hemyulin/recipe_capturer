import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cookbuk/data/meal_plan_repository.dart';
import 'package:cookbuk/data/recipe_repository.dart';
import 'package:cookbuk/domain/recipe.dart';
import 'package:cookbuk/ui/pages/recipe_camera_import_page.dart';
import 'package:cookbuk/ui/widgets/backend_connection_icon.dart';
import 'package:cookbuk/ui/widgets/load_state_view.dart';
import 'package:cookbuk/ui/widgets/recipe_card.dart';

class RecipeListPage extends StatefulWidget {
  const RecipeListPage({
    super.key,
    required this.title,
    required this.repo,
    this.mealPlanRepo,
  });

  final String title;
  final RecipeRepository repo;
  final MealPlanRepository? mealPlanRepo;

  @override
  State<RecipeListPage> createState() => _RecipeListPageState();
}

class _RecipeListPageState extends State<RecipeListPage> {
  List<Recipe> recipesSnapshot = [];
  final TextEditingController _searchController = TextEditingController();
  bool _favoritesOnly = false;
  bool _isCreateMenuOpen = false;
  bool _isImporting = false;
  bool _isLoading = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final snapshot = await widget.repo.getAll();
      snapshot.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      setState(() {
        recipesSnapshot = snapshot;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Backend nicht erreichbar.';
      });
    }
  }

  Future<void> _handleCreateAction(_RecipeCreateAction action) async {
    if (_isImporting) return;
    setState(() => _isCreateMenuOpen = false);

    if (action == _RecipeCreateAction.manual) {
      final saved = await context.push<bool>('/new');
      if (saved == true) await _refresh();
      return;
    }

    final source = switch (action) {
      _RecipeCreateAction.camera => _RecipeImportSource.camera,
      _RecipeCreateAction.gallery => _RecipeImportSource.gallery,
      _RecipeCreateAction.manual => throw StateError('Handled above'),
    };
    await _importRecipeFromPhoto(source);
  }

  Future<void> _importRecipeFromPhoto(_RecipeImportSource source) async {
    final importRepo = widget.repo is RecipeAiImportRepository
        ? widget.repo as RecipeAiImportRepository
        : null;
    if (importRepo == null || _isImporting) return;

    final imagePaths = await _pickImportImages(source);
    if (imagePaths.isEmpty || !mounted) return;

    setState(() => _isImporting = true);
    var isProgressDialogVisible = true;
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _RecipeImportProgressDialog(),
      ).whenComplete(() => isProgressDialogVisible = false),
    );
    await Future<void>.delayed(Duration.zero);

    void closeProgressDialog() {
      if (!mounted || !isProgressDialogVisible) return;
      Navigator.of(context, rootNavigator: true).pop();
      isProgressDialogVisible = false;
    }

    try {
      final draft = await importRepo.importFromImages(imagePaths: imagePaths);
      if (!mounted) return;
      closeProgressDialog();
      final saved = await context.push<bool>('/new', extra: draft);
      if (saved == true) await _refresh();
    } catch (error) {
      if (!mounted) return;
      closeProgressDialog();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_importErrorMessage(error))));
    } finally {
      closeProgressDialog();
      if (mounted) setState(() => _isImporting = false);
    }
  }

  String _importErrorMessage(Object error) {
    if (error is RecipeSaveException) return error.userMessage;
    return 'Rezept konnte nicht aus dem Bild erstellt werden.';
  }

  Future<List<String>> _pickImportImages(_RecipeImportSource source) async {
    if (source == _RecipeImportSource.gallery) {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage(limit: _maxImportImages);
      return images.map((image) => image.path).take(_maxImportImages).toList();
    }

    return await Navigator.of(context).push<List<String>>(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) =>
                const RecipeCameraImportPage(maxImages: _maxImportImages),
          ),
        ) ??
        const [];
  }

  List<Recipe> _filteredRecipes() {
    final query = _searchController.text.trim().toLowerCase();

    return recipesSnapshot.where((recipe) {
      if (_favoritesOnly && !recipe.isFavorite) return false;

      if (query.isEmpty) return true;

      final inTitle = recipe.title.toLowerCase().contains(query);
      final inIngredients = recipe.ingredients.any(
        (ingredient) => ingredient.matches(query),
      );
      final inTags = recipe.tags.any(
        (tag) => tag.toLowerCase().contains(query),
      );

      return inTitle || inIngredients || inTags;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final filteredRecipes = _filteredRecipes();
    final hasAnyRecipe = recipesSnapshot.isNotEmpty;
    final needsReviewCount = recipesSnapshot.where(_needsReview).length;

    final Widget content = _isLoading
        ? const LoadStateView.loading()
        : _loadError != null
        ? LoadStateView.error(
            title: 'Rezepte konnten nicht geladen werden',
            message:
                'Prüfe, ob der CookBuk-Backendserver läuft und dein Gerät im Tailscale ist.',
            onRetry: _refresh,
          )
        : !hasAnyRecipe
        ? _EmptyLibraryState(title: 'Noch keine Rezepte')
        : filteredRecipes.isEmpty
        ? _EmptyLibraryState(title: 'Keine Treffer')
        : LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 900
                  ? 3
                  : constraints.maxWidth >= 620
                  ? 2
                  : 1;

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 14,
                  mainAxisSpacing: 14,
                  childAspectRatio: columns == 1
                      ? 1.1
                      : columns == 2
                      ? 1.08
                      : 0.92,
                ),
                itemCount: filteredRecipes.length,
                itemBuilder: (context, index) {
                  final recipe = filteredRecipes[index];
                  return RecipeCard(
                    recipe: recipe,
                    onTap: () async {
                      await context.push('/details', extra: recipe);
                      await _refresh();
                    },
                  );
                },
              );
            },
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (widget.mealPlanRepo != null)
            BackendConnectionIcon(mealPlanRepo: widget.mealPlanRepo!),
        ],
      ),
      floatingActionButton: _RecipeCreateFan(
        isOpen: _isCreateMenuOpen,
        isBusy: _isImporting,
        onToggle: () => setState(() => _isCreateMenuOpen = !_isCreateMenuOpen),
        onAction: _handleCreateAction,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Titel, Zutat oder Tag',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.close_rounded),
                        tooltip: 'Suche löschen',
                      ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (needsReviewCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer.withValues(
                          alpha: 0.96,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        '$needsReviewCount offen',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  FilterChip(
                    label: const Text('Favoriten'),
                    selected: _favoritesOnly,
                    onSelected: (value) {
                      setState(() => _favoritesOnly = value);
                    },
                  ),
                ],
              ),
            ),
          ),
          Expanded(child: content),
        ],
      ),
    );
  }
}

enum _RecipeImportSource { camera, gallery }

enum _RecipeCreateAction { camera, gallery, manual }

class _RecipeCreateFan extends StatelessWidget {
  const _RecipeCreateFan({
    required this.isOpen,
    required this.isBusy,
    required this.onToggle,
    required this.onAction,
  });

  final bool isOpen;
  final bool isBusy;
  final VoidCallback onToggle;
  final void Function(_RecipeCreateAction action) onAction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 172,
      height: 172,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          _FanActionButton(
            isVisible: isOpen,
            right: 86,
            bottom: 4,
            icon: Icons.edit_note_outlined,
            tooltip: 'Manuell',
            onPressed: () => onAction(_RecipeCreateAction.manual),
          ),
          _FanActionButton(
            isVisible: isOpen,
            right: 64,
            bottom: 64,
            icon: Icons.photo_library_outlined,
            tooltip: 'Bilder auswählen',
            onPressed: () => onAction(_RecipeCreateAction.gallery),
          ),
          _FanActionButton(
            isVisible: isOpen,
            right: 4,
            bottom: 86,
            icon: Icons.photo_camera_outlined,
            tooltip: 'Foto aufnehmen',
            onPressed: () => onAction(_RecipeCreateAction.camera),
          ),
          FloatingActionButton(
            onPressed: isBusy ? null : onToggle,
            tooltip: 'Rezept hinzufügen',
            child: isBusy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  )
                : AnimatedRotation(
                    turns: isOpen ? 0.125 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(Icons.add_rounded),
                  ),
          ),
        ],
      ),
    );
  }
}

class _FanActionButton extends StatelessWidget {
  const _FanActionButton({
    required this.isVisible,
    required this.right,
    required this.bottom,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final bool isVisible;
  final double right;
  final double bottom;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 210),
      curve: Curves.easeOutCubic,
      right: isVisible ? right : 0,
      bottom: isVisible ? bottom : 0,
      child: AnimatedScale(
        scale: isVisible ? 1 : 0.72,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        child: IgnorePointer(
          ignoring: !isVisible,
          child: AnimatedOpacity(
            opacity: isVisible ? 1 : 0,
            duration: const Duration(milliseconds: 140),
            child: FloatingActionButton.small(
              heroTag: tooltip,
              onPressed: onPressed,
              tooltip: tooltip,
              backgroundColor: colorScheme.surfaceContainerLow,
              foregroundColor: colorScheme.onSurface,
              child: Icon(icon),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecipeImportProgressDialog extends StatefulWidget {
  const _RecipeImportProgressDialog();

  @override
  State<_RecipeImportProgressDialog> createState() =>
      _RecipeImportProgressDialogState();
}

class _RecipeImportProgressDialogState
    extends State<_RecipeImportProgressDialog> {
  static const _messages = [
    'Die KI kocht gerade vor sich hin...',
    'Ich entziffere die Küchenhieroglyphen...',
    'Kurz prüfen, ob das Ding koscher wirkt...',
    'Zutaten werden liebevoll geradegerückt...',
    'Ich suche den roten Faden im Rezeptchaos...',
    'Noch ein bisschen Magie im Topf...',
    'Einkaufsliste wird heimlich mitgedacht...',
    'Der digitale Kochlöffel wird geschwungen...',
    'Ich trenne Rezept von Randnotizen...',
    'Einmal kurz mit Küchenintuition abschmecken...',
    'Ich prüfe, ob aus dem Foto wirklich Essen wird...',
    'Die KI fragt sich, ob das eine Prise oder Mut war...',
    'Mengen werden aus dem Nebel gezogen...',
    'Ich mache aus Foto-Chaos ein Rezept...',
    'Der Topf simmert, die Bits arbeiten...',
  ];

  Timer? _timer;
  final Random _random = Random();
  late var _messageIndex = _random.nextInt(_messages.length);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() {
        var nextIndex = _random.nextInt(_messages.length);
        if (_messages.length > 1) {
          while (nextIndex == _messageIndex) {
            nextIndex = _random.nextInt(_messages.length);
          }
        }
        _messageIndex = nextIndex;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: false,
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 56,
                height: 56,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'KI erstellt dein Rezept',
                textAlign: TextAlign.center,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 260),
                child: Text(
                  _messages[_messageIndex],
                  key: ValueKey(_messageIndex),
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Bitte App offen lassen.',
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _maxImportImages = 5;

bool _needsReview(Recipe recipe) {
  final hasIngredients = recipe.ingredients.isNotEmpty;
  final hasInstructions = recipe.instructions.isNotEmpty;
  return !hasIngredients || !hasInstructions;
}

class _EmptyLibraryState extends StatelessWidget {
  const _EmptyLibraryState({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.outlineVariant.withValues(alpha: 0.75),
                  ),
                ),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
