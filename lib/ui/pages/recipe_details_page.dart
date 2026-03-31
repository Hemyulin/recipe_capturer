import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_capturer/data/recipe_repository.dart';
import 'package:recipe_capturer/domain/recipe.dart';
import 'package:recipe_capturer/ui/formatters/date_label_de.dart';
import 'package:recipe_capturer/ui/formatters/strings_de.dart';
import 'package:recipe_capturer/ui/formatters/tag_label_de.dart';

class RecipeDetailsPage extends StatefulWidget {
  final Recipe recipe;
  final RecipeRepository repo;

  const RecipeDetailsPage({
    super.key,
    required this.recipe,
    required this.repo,
  });

  @override
  State<RecipeDetailsPage> createState() => _RecipeDetailsPageState();
}

class _RecipeDetailsPageState extends State<RecipeDetailsPage> {
  late Recipe recipe;

  @override
  void initState() {
    super.initState();
    recipe = widget.recipe;
  }

  Future<void> _toggleFavorite() async {
    final next = recipe.withFavorite(!recipe.isFavorite);
    setState(() => recipe = next);
    await widget.repo.update(next);
  }

  Future<void> _editRecipe() async {
    final saved = await context.push<bool>('/edit', extra: recipe);

    if (!context.mounted) return;

    if (saved == true) {
      final refreshed = await widget.repo.getAll();
      final updated = refreshed.where((r) => r.id == recipe.id).firstOrNull;

      if (!context.mounted) return;

      if (updated != null) {
        setState(() => recipe = updated);
      }
    }
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

    if (confirmed == true) {
      await widget.repo.deleteById(recipe.id);
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  Widget _buildMainImage() {
    final hasImages = recipe.imagePaths.isNotEmpty;

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Material(
            elevation: 2,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: hasImages
                ? Image.file(
                    File(recipe.imagePaths.first),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Image.asset(
                      'assets/recipe_placeholder.jpg',
                      fit: BoxFit.cover,
                    ),
                  )
                : Image.asset(
                    'assets/recipe_placeholder.jpg',
                    fit: BoxFit.cover,
                  ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Material(
              color: Colors.black38,
              shape: const CircleBorder(),
              child: IconButton(
                onPressed: _toggleFavorite,
                icon: Icon(
                  recipe.isFavorite ? Icons.favorite : Icons.favorite_border,
                ),
                color: Colors.redAccent,
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

  Widget _buildImageGallery() {
    if (recipe.imagePaths.length <= 1) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const Text(
          'Originalbilder',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recipe.imagePaths.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final path = recipe.imagePaths[index];

              return ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image.file(
                    File(path),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const ColoredBox(
                      color: Colors.black12,
                      child: Center(child: Icon(Icons.broken_image_outlined)),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateLabel = dateLabelDe(recipe.createdAt, now);
    final meta =
        '${StringsDe.addedLabel}: $dateLabel   ${StringsDe.ingredientsLabel}: ${recipe.ingredients.length}';

    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                _editRecipe();
              } else if (value == 'delete') {
                _confirmAndDelete();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
              PopupMenuItem(value: 'delete', child: Text('Löschen')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          _buildMainImage(),
          _buildImageGallery(),
          const SizedBox(height: 16),
          Text(
            meta,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          if (recipe.tags.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: recipe.tags
                  .map(
                    (t) => Chip(
                      label: Text(tagLabelDe(t)),
                      backgroundColor: colorScheme.surfaceContainerHighest,
                      side: BorderSide.none,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                  .toList(),
            ),
          if (recipe.tags.isNotEmpty) const SizedBox(height: 24),
          Text('Zutaten', style: textTheme.titleMedium),
          const SizedBox(height: 12),
          if (recipe.ingredients.isEmpty)
            Text(
              StringsDe.noIngredients,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: recipe.ingredients
                  .map(
                    (ingredient) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        '• $ingredient',
                        style: textTheme.bodyMedium?.copyWith(height: 1.35),
                      ),
                    ),
                  )
                  .toList(),
            ),
          if (recipe.instructions.trim().isNotEmpty) ...[
            const SizedBox(height: 24),
            Text('Zubereitung', style: textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(
              recipe.instructions,
              style: textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ],
        ],
      ),
    );
  }
}
