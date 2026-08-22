import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_capturer/data/recipe_repository.dart';
import 'package:recipe_capturer/domain/recipe.dart';
import 'package:recipe_capturer/ui/widgets/recipe_card.dart';

class RecipeListPage extends StatefulWidget {
  const RecipeListPage({super.key, required this.title, required this.repo});

  final String title;
  final RecipeRepository repo;

  @override
  State<RecipeListPage> createState() => _RecipeListPageState();
}

class _RecipeListPageState extends State<RecipeListPage> {
  List<Recipe> recipesSnapshot = [];
  final TextEditingController _searchController = TextEditingController();
  bool _favoritesOnly = false;
  bool _withImagesOnly = false;

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
    final snapshot = await widget.repo.getAll();
    snapshot.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (!mounted) return;
    setState(() => recipesSnapshot = snapshot);
  }

  List<Recipe> _filteredRecipes() {
    final query = _searchController.text.trim().toLowerCase();

    return recipesSnapshot.where((recipe) {
      if (_favoritesOnly && !recipe.isFavorite) return false;
      if (_withImagesOnly && recipe.imagePaths.isEmpty) return false;

      if (query.isEmpty) return true;

      final inTitle = recipe.title.toLowerCase().contains(query);
      final inIngredients = recipe.ingredients.any(
        (ingredient) => ingredient.toLowerCase().contains(query),
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

    final Widget content = !hasAnyRecipe
        ? _EmptyLibraryState(title: 'Noch keine Rezepte')
        : filteredRecipes.isEmpty
        ? _EmptyLibraryState(title: 'Keine Treffer')
        : ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 120),
            itemCount: filteredRecipes.length,
            itemBuilder: (context, index) {
              final recipe = filteredRecipes[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: RecipeCard(
                  recipe: recipe,
                  onTap: () async {
                    await context.push('/details', extra: recipe);
                    await _refresh();
                  },
                ),
              );
            },
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
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
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLowest.withValues(
                        alpha: 0.94,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
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
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
              ],
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
  final hasInstructions = recipe.instructions.trim().length >= 40;
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
