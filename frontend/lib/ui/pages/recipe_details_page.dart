import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cookbuk/data/recipe_repository.dart';
import 'package:cookbuk/domain/recipe.dart';
import 'package:cookbuk/ui/formatters/tag_label_de.dart';
import 'package:cookbuk/ui/widgets/recipe_image.dart';

class RecipeDetailsPage extends StatefulWidget {
  const RecipeDetailsPage({
    super.key,
    required this.recipe,
    required this.repo,
  });

  final Recipe recipe;
  final RecipeRepository repo;

  @override
  State<RecipeDetailsPage> createState() => _RecipeDetailsPageState();
}

class _RecipeDetailsPageState extends State<RecipeDetailsPage> {
  late Recipe recipe;
  final Set<int> _checkedIngredients = <int>{};
  final Set<int> _checkedSteps = <int>{};

  @override
  void initState() {
    super.initState();
    recipe = widget.recipe;
  }

  Future<void> _refreshRecipe() async {
    final refreshed = await widget.repo.getAll();
    final updated = refreshed.where((r) => r.id == recipe.id).firstOrNull;
    if (!mounted || updated == null) return;
    setState(() => recipe = updated);
  }

  Future<void> _toggleFavorite() async {
    final next = recipe.withFavorite(!recipe.isFavorite);
    setState(() => recipe = next);
    await widget.repo.update(next);
  }

  Future<void> _editRecipe() async {
    final saved = await context.push<bool>('/edit', extra: recipe);
    if (!mounted) return;
    if (saved == true) await _refreshRecipe();
  }

  Future<void> _addMainImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final updatedRecipe = recipe.copyWith(
      imagePaths: [picked.path, ...recipe.imagePaths.skip(1)],
    );
    await widget.repo.update(updatedRecipe);
    await _refreshRecipe();
  }

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rezept löschen?'),
        content: const Text('Dieses Rezept wird dauerhaft gelöscht.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Abbrechen'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    await widget.repo.deleteById(recipe.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _showStats() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Statistiken'),
        content: _RecipeStatsContent(recipe: recipe),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }

  Widget _buildMainImage(ColorScheme colorScheme) {
    final imagePath = recipe.mainImagePath;

    return AspectRatio(
      aspectRatio: 16 / 10,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Material(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(24),
            clipBehavior: Clip.antiAlias,
            child: RecipeImage(path: imagePath),
          ),
          if (imagePath == null)
            Positioned.fill(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _addMainImage,
                  child: Center(
                    child: FilledButton.icon(
                      onPressed: _addMainImage,
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('Foto hinzufügen'),
                    ),
                  ),
                ),
              ),
            ),
          if (imagePath != null)
            Positioned(
              left: 12,
              bottom: 12,
              child: FilledButton.icon(
                onPressed: _addMainImage,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Ändern'),
              ),
            ),
          Positioned(
            top: 12,
            right: 12,
            child: Material(
              color: colorScheme.surface.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(14),
              child: IconButton(
                onPressed: _toggleFavorite,
                icon: Icon(
                  recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
                ),
                color: colorScheme.secondary,
                tooltip: recipe.isFavorite
                    ? 'Favorit entfernen'
                    : 'Als Favorit markieren',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
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
    final textTheme = Theme.of(context).textTheme;
    final totalTime = recipe.totalTimeMinutes;

    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title),
        actions: [
          IconButton(
            onPressed: _editRecipe,
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Bearbeiten',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'stats') _showStats();
              if (value == 'photo') _addMainImage();
              if (value == 'delete') _confirmAndDelete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'stats', child: Text('Statistiken')),
              PopupMenuItem(value: 'photo', child: Text('Foto ändern')),
              PopupMenuItem(value: 'delete', child: Text('Löschen')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _buildMainImage(colorScheme),
          const SizedBox(height: 16),
          Text(recipe.title, style: textTheme.headlineSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (recipe.servings != null)
                _InfoPill(
                  icon: Icons.people_alt_outlined,
                  label: '${recipe.servings} Portionen',
                ),
              if (recipe.prepTimeMinutes != null)
                _InfoPill(
                  icon: Icons.countertops_outlined,
                  label: '${recipe.prepTimeMinutes} min Vorbereitung',
                ),
              if (recipe.cookTimeMinutes != null)
                _InfoPill(
                  icon: Icons.soup_kitchen_outlined,
                  label: '${recipe.cookTimeMinutes} min Kochen',
                ),
              if (totalTime != null)
                _InfoPill(
                  icon: Icons.schedule_outlined,
                  label: '$totalTime min',
                ),
              if (recipe.season.isNotEmpty)
                _InfoPill(icon: Icons.eco_outlined, label: recipe.season),
            ],
          ),
          if (recipe.tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: recipe.tags
                  .map((tag) => Chip(label: Text(tagLabelDe(tag))))
                  .toList(),
            ),
          ],
          const SizedBox(height: 16),
          _buildSection(
            title: 'Zutaten',
            child: recipe.ingredients.isEmpty
                ? Text(
                    'Noch keine Zutaten',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  )
                : Column(
                    children: List.generate(recipe.ingredients.length, (index) {
                      final ingredient = recipe.ingredients[index];
                      final checked = _checkedIngredients.contains(index);
                      return CheckboxListTile(
                        value: checked,
                        onChanged: (_) {
                          setState(() {
                            if (!checked) {
                              _checkedIngredients.add(index);
                            } else {
                              _checkedIngredients.remove(index);
                            }
                          });
                        },
                        title: Text(ingredient.label),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      );
                    }),
                  ),
          ),
          const SizedBox(height: 14),
          _buildSection(
            title: 'Zubereitung',
            child: recipe.instructions.isEmpty
                ? Text(
                    'Noch keine Schritte',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  )
                : Column(
                    children: List.generate(recipe.instructions.length, (
                      index,
                    ) {
                      final checked = _checkedSteps.contains(index);
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(child: Text('${index + 1}')),
                        title: Text(
                          recipe.instructions[index],
                          style: checked
                              ? textTheme.bodyLarge?.copyWith(
                                  decoration: TextDecoration.lineThrough,
                                  color: colorScheme.onSurfaceVariant,
                                )
                              : textTheme.bodyLarge,
                        ),
                        onTap: () {
                          setState(() {
                            if (!checked) {
                              _checkedSteps.add(index);
                            } else {
                              _checkedSteps.remove(index);
                            }
                          });
                        },
                      );
                    }),
                  ),
          ),
          if (recipe.notes.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildSection(title: 'Notizen', child: Text(recipe.notes)),
          ],
        ],
      ),
    );
  }
}

String _formatDate(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  return '$day.$month.${value.year}';
}

class _RecipeStatsContent extends StatelessWidget {
  const _RecipeStatsContent({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final lastCookedAt = recipe.lastCookedAt;
    final mealCounts = <String, int>{};

    for (final event in recipe.cookEvents) {
      final mealType = event.mealType.isEmpty ? 'Unbekannt' : event.mealType;
      mealCounts[mealType] = (mealCounts[mealType] ?? 0) + 1;
    }

    if (recipe.cookCount == 0) {
      return Text(
        'Noch keine Kochhistorie. Später zählen wir automatisch, wenn ein geplanter Tag abgeschlossen ist.',
        style: textTheme.bodyMedium,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Insgesamt: ${recipe.cookCount}x', style: textTheme.bodyLarge),
        if (lastCookedAt != null) ...[
          const SizedBox(height: 8),
          Text('Zuletzt: ${_formatDate(lastCookedAt)}'),
        ],
        if (mealCounts.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text('Nach Mahlzeit', style: textTheme.titleSmall),
          const SizedBox(height: 6),
          ...mealCounts.entries.map(
            (entry) => Text('${entry.key}: ${entry.value}x'),
          ),
        ],
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}
