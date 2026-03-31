import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:recipe_capturer/data/recipe_repository.dart';
import 'package:recipe_capturer/domain/recipe.dart';
import 'package:recipe_capturer/ui/widgets/recipe_card.dart';
import 'package:recipe_capturer/ui/formatters/strings_de.dart';

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
    final textTheme = Theme.of(context).textTheme;
    final filteredRecipes = _filteredRecipes();
    final hasAnyRecipe = recipesSnapshot.isNotEmpty;

    final Widget content = !hasAnyRecipe
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  size: 44,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 10),
                Text(
                  StringsDe.noRecipes,
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          )
        : filteredRecipes.isEmpty
        ? const Center(
            child: Text('Keine Treffer. Suche oder Filter anpassen.'),
          )
        : ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: filteredRecipes.length,
            itemBuilder: (context, index) {
              final recipe = filteredRecipes[index];
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
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
          final picker = ImagePicker();
          final images = await picker.pickMultiImage();

          if (images.isEmpty) return;

          final paths = images.map((e) => e.path).toList();

          if (!context.mounted) return;
          final imported = await context.push<bool>('/import', extra: paths);

          if (!context.mounted) return;
          if (imported == true) {
            await _refresh();
          }
        },
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Aus Bildern importieren'),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  colorScheme.primaryContainer,
                  colorScheme.tertiaryContainer.withValues(alpha: 0.65),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: colorScheme.surface.withValues(alpha: 0.8),
                  child: Icon(
                    Icons.restaurant_menu,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${filteredRecipes.length} Rezepte',
                        style: textTheme.titleMedium,
                      ),
                      Text(
                        'Screenshot -> OCR -> Prüfen -> Speichern',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Suchen (Titel, Zutat, Tag)',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                            icon: const Icon(Icons.clear),
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
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
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
