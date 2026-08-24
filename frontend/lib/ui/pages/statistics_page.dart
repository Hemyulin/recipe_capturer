import 'package:flutter/material.dart';
import 'package:cookbuk/data/recipe_repository.dart';
import 'package:cookbuk/domain/recipe.dart';

class StatisticsPage extends StatefulWidget {
  const StatisticsPage({super.key, required this.repo});

  final RecipeRepository repo;

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  late final Future<List<Recipe>> _recipesFuture = widget.repo.getAll();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statistiken')),
      body: FutureBuilder<List<Recipe>>(
        future: _recipesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Statistiken nicht erreichbar.'));
          }

          final recipes = snapshot.data ?? const <Recipe>[];
          final favoriteCount = recipes
              .where((recipe) => recipe.isFavorite)
              .length;
          final reviewCount = recipes.where(_needsReview).length;
          final totalCookEvents = recipes.fold<int>(
            0,
            (sum, recipe) => sum + recipe.cookCount,
          );
          final cookedRecipes =
              recipes.where((recipe) => recipe.cookCount > 0).toList()
                ..sort((a, b) => b.cookCount.compareTo(a.cookCount));
          final favoriteMeal = cookedRecipes.isEmpty
              ? null
              : cookedRecipes.first;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _StatsGrid(
                items: [
                  _StatsItem(
                    icon: Icons.menu_book_outlined,
                    label: 'Rezepte',
                    value: recipes.length.toString(),
                  ),
                  _StatsItem(
                    icon: Icons.restaurant_menu_outlined,
                    label: 'Gekocht',
                    value: totalCookEvents.toString(),
                  ),
                  _StatsItem(
                    icon: Icons.favorite_border_rounded,
                    label: 'Favoriten',
                    value: favoriteCount.toString(),
                  ),
                  _StatsItem(
                    icon: Icons.rate_review_outlined,
                    label: 'Offen',
                    value: reviewCount.toString(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _StatsCard(
                title: 'Lieblingsessen',
                child: favoriteMeal == null
                    ? const Text('Noch keine Kochhistorie.')
                    : ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(favoriteMeal.title),
                        subtitle: Text('${favoriteMeal.cookCount}x gekocht'),
                        leading: const Icon(Icons.star_outline_rounded),
                      ),
              ),
              const SizedBox(height: 14),
              _StatsCard(
                title: 'Meist gekocht',
                child: cookedRecipes.isEmpty
                    ? const Text('Noch nichts gezählt.')
                    : Column(
                        children: [
                          for (final recipe in cookedRecipes.take(5))
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(recipe.title),
                              trailing: Text('${recipe.cookCount}x'),
                            ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  const _StatsGrid({required this.items});

  final List<_StatsItem> items;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.8,
      children: [for (final item in items) _StatsTile(item: item)],
    );
  }
}

class _StatsTile extends StatelessWidget {
  const _StatsTile({required this.item});

  final _StatsItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(item.icon, color: colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.value,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    item.label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _StatsItem {
  const _StatsItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

bool _needsReview(Recipe recipe) {
  return recipe.tags.contains('needs_review') ||
      recipe.ingredients.isEmpty ||
      recipe.instructions.isEmpty;
}
