import 'dart:io';

import 'package:flutter/material.dart';
import 'package:recipe_capturer/domain/recipe.dart';
import 'package:recipe_capturer/ui/formatters/date_label_de.dart';
import 'package:recipe_capturer/ui/formatters/strings_de.dart';
import 'package:recipe_capturer/ui/formatters/tag_label_de.dart';

class RecipeCard extends StatelessWidget {
  const RecipeCard({
    super.key,
    required this.recipe,
    this.onTap,
    this.onDelete,
  });

  final Recipe recipe;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateLabel = dateLabelDe(recipe.createdAt, now);

    final meta =
        '${StringsDe.addedLabel}: $dateLabel   ${StringsDe.ingredientsLabel}: ${recipe.ingredients.length}';

    const radius = 22.0;
    final colorScheme = Theme.of(context).colorScheme;

    Future<void> confirmDelete() async {
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
        onDelete?.call();
      }
    }

    final imageWidget = recipe.imagePaths.isNotEmpty
        ? Image.file(
            File(recipe.imagePaths.first),
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, _, _) => Image.asset(
              'assets/recipe_placeholder.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          )
        : Image.asset(
            'assets/recipe_placeholder.jpg',
            fit: BoxFit.cover,
            alignment: Alignment.center,
          );

    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.45),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  imageWidget,
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.48),
                          Colors.black.withValues(alpha: 0.84),
                        ],
                      ),
                    ),
                  ),
                  if (recipe.isFavorite)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.black38,
                        shape: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            Icons.favorite,
                            color: Colors.redAccent,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  if (onDelete != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Material(
                        color: Colors.black45,
                        shape: const CircleBorder(),
                        child: IconButton(
                          onPressed: confirmDelete,
                          icon: const Icon(Icons.delete_outline),
                          color: Colors.white,
                          tooltip: 'Löschen',
                        ),
                      ),
                    ),
                  Positioned(
                    left: 12,
                    right: 12,
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (recipe.tags.isNotEmpty)
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: recipe.tags
                                .take(4)
                                .map(
                                  (t) => Chip(
                                    label: Text(
                                      tagLabelDe(t),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    backgroundColor: Colors.white.withValues(
                                      alpha: 0.88,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                )
                                .toList(),
                          ),
                        if (recipe.tags.isNotEmpty) const SizedBox(height: 8),
                        Text(
                          recipe.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      meta,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
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
