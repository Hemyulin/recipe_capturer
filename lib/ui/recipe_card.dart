import 'package:flutter/material.dart';
import 'package:recipe_capturer/domain/recipe.dart';
import 'package:recipe_capturer/ui/date_label_de.dart';
import 'package:recipe_capturer/ui/strings_de.dart';

class RecipeCard extends StatelessWidget {
  const RecipeCard({Key? key, required this.recipe, this.onTap, this.onDelete})
    : super(key: key);

  final Recipe recipe;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateLabel = dateLabelDe(recipe.createdAt, now);

    final meta =
        '${StringsDe.addedLabel}: $dateLabel  ·  ${StringsDe.ingredientsLabel}: ${recipe.ingredients.length}';

    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        title: Text(recipe.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
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
                          label: Text(t),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      )
                      .toList(),
                ),
              if (recipe.tags.isNotEmpty) const SizedBox(height: 8),
              Text(meta),
            ],
          ),
        ),
        onTap: onTap,
        leading: SizedBox(
          width: 88,
          height: 88,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/recipe_placeholder.jpg',
              fit: BoxFit.cover,
            ),
          ),
        ),
        trailing: onDelete == null
            ? null
            : IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
              ),
      ),
    );
  }
}
