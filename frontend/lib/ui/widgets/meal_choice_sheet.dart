import 'package:flutter/material.dart';
import 'package:cookbuk/domain/recipe.dart';
import 'package:cookbuk/ui/widgets/recipe_image.dart';

class MealChoiceSheet extends StatefulWidget {
  const MealChoiceSheet({super.key, required this.recipes});

  static const leftoversValue = '__leftovers__';
  static const leftoversImagePath = 'assets/demo_recipes/leftovers.png';

  final List<Recipe> recipes;

  @override
  State<MealChoiceSheet> createState() => _MealChoiceSheetState();
}

class _MealChoiceSheetState extends State<MealChoiceSheet> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Recipe> _filteredRecipes() {
    final query = _searchController.text.trim().toLowerCase();
    final sortedRecipes = [...widget.recipes]
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    if (query.isEmpty) return sortedRecipes;

    return sortedRecipes.where((recipe) {
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
    final filteredRecipes = _filteredRecipes();

    return SafeArea(
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: filteredRecipes.isEmpty ? 4 : filteredRecipes.length + 3,
        separatorBuilder: (_, index) =>
            index <= 1 ? const SizedBox(height: 8) : const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Text(
              'Rezept auswählen',
              style: Theme.of(context).textTheme.titleLarge,
            );
          }

          if (index == 1) {
            return TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Suchen',
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
            );
          }

          if (index == 2) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: const SizedBox(
                  width: 56,
                  height: 56,
                  child: RecipeImage(path: MealChoiceSheet.leftoversImagePath),
                ),
              ),
              title: const Text('Reste'),
              subtitle: const Text('Keine Rezeptauswahl für diese Mahlzeit'),
              onTap: () =>
                  Navigator.of(context).pop(MealChoiceSheet.leftoversValue),
            );
          }

          if (filteredRecipes.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'Keine Treffer',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }

          final recipe = filteredRecipes[index - 3];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 56,
                height: 56,
                child: RecipeImage(
                  path: recipe.mainImagePath,
                  placeholderSeed: recipe.id,
                  cacheKey: recipeImageCacheKey(recipe),
                ),
              ),
            ),
            title: Text(recipe.title),
            subtitle: Text(
              [
                '${recipe.ingredients.length} Zutaten',
                if (recipe.totalTimeMinutes != null)
                  '${recipe.totalTimeMinutes} min',
              ].join(' · '),
            ),
            onTap: () => Navigator.of(context).pop(recipe.id),
          );
        },
      ),
    );
  }
}

class UnplannedMealImage extends StatelessWidget {
  const UnplannedMealImage({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: colorScheme.surfaceContainerHigh,
      child: Center(
        child: Icon(
          Icons.add_rounded,
          color: colorScheme.primary,
          size: 34,
          semanticLabel: '$title planen',
        ),
      ),
    );
  }
}
