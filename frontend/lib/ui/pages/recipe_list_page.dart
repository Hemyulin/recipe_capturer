import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cookbuk/data/meal_plan_repository.dart';
import 'package:cookbuk/data/recipe_repository.dart';
import 'package:cookbuk/domain/recipe.dart';
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
  bool _withImagesOnly = false;
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

  List<Recipe> _filteredRecipes() {
    final query = _searchController.text.trim().toLowerCase();

    return recipesSnapshot.where((recipe) {
      if (_favoritesOnly && !recipe.isFavorite) return false;
      if (_withImagesOnly && recipe.imagePaths.isEmpty) return false;

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
                      ? 1
                      : columns == 2
                      ? 1.02
                      : 0.82,
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
          IconButton(
            onPressed: () async {
              final saved = await context.push<bool>('/new');
              if (saved == true) await _refresh();
            },
            tooltip: 'Manuell erstellen',
            icon: const Icon(Icons.edit_note_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final saved = await context.push<bool>('/new');
          if (saved == true) await _refresh();
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Rezept hinzufügen'),
      ),
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
                  FilterChip(
                    label: const Text('Mit Bildern'),
                    selected: _withImagesOnly,
                    onSelected: (value) {
                      setState(() => _withImagesOnly = value);
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
