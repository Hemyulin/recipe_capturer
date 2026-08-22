import 'dart:io';

import 'package:flutter/material.dart';
import 'package:recipe_capturer/domain/recipe.dart';
import 'package:recipe_capturer/ui/formatters/date_label_de.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final dateLabel = dateLabelDe(recipe.createdAt, DateTime.now());
    final hasImage = recipe.imagePaths.isNotEmpty;
    final needsReview = _needsReview(recipe);
    final reviewNotes = _reviewNotes(recipe);

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

    return Card(
      margin: EdgeInsets.zero,
      color: colorScheme.surfaceContainerLowest.withValues(alpha: 0.96),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  width: 96,
                  height: 104,
                  child: hasImage
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
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            recipe.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.titleMedium?.copyWith(
                              height: 1.1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (recipe.isFavorite)
                          Padding(
                            padding: const EdgeInsets.only(left: 8, top: 1),
                            child: Icon(
                              Icons.favorite,
                              size: 18,
                              color: colorScheme.secondary,
                            ),
                          ),
                        if (onDelete != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: IconButton(
                              onPressed: confirmDelete,
                              icon: const Icon(Icons.delete_outline),
                              tooltip: 'Löschen',
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatusPill(
                          label: needsReview ? 'Prüfen' : 'Bereit',
                          backgroundColor: needsReview
                              ? colorScheme.tertiaryContainer
                              : colorScheme.primaryContainer,
                          foregroundColor: needsReview
                              ? colorScheme.onTertiaryContainer
                              : colorScheme.onPrimaryContainer,
                          onTap: needsReview
                              ? () => _showReviewDetailsSheet(
                                  context,
                                  reviewNotes,
                                )
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${recipe.ingredients.length} Zutaten',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          dateLabel,
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (hasImage) ...[
                          Text(
                            '  •  ',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            '${recipe.imagePaths.length} Bild${recipe.imagePaths.length == 1 ? '' : 'er'}',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    this.onTap,
  });

  final String label;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: backgroundColor.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

void _showReviewDetailsSheet(BuildContext context, List<String> notes) {
  final textTheme = Theme.of(context).textTheme;
  final colorScheme = Theme.of(context).colorScheme;

  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Noch prüfen', style: textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Dieses Rezept wirkt noch nicht ganz vollständig.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            ...notes.map(
              (note) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '•',
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.secondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(note, style: textTheme.bodyMedium)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

List<String> _reviewNotes(Recipe recipe) {
  final notes = <String>[];

  if (recipe.ingredients.isEmpty) {
    notes.add('Es fehlen Zutaten.');
  }
  if (recipe.instructions.trim().isEmpty) {
    notes.add('Es fehlt eine Zubereitung.');
  } else if (recipe.instructions.trim().length < 40) {
    notes.add('Die Zubereitung wirkt noch unvollständig.');
  }
  return notes.isEmpty
      ? ['Bitte kurz prüfen, ob alles vollständig ist.']
      : notes;
}

bool _needsReview(Recipe recipe) {
  final hasIngredients = recipe.ingredients.isNotEmpty;
  final hasInstructions = recipe.instructions.trim().length >= 40;
  return !hasIngredients || !hasInstructions;
}
