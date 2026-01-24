import 'package:flutter/material.dart';
import 'package:recipe_capturer/domain/recipe.dart';

class RecipeCard extends StatelessWidget {
  const RecipeCard({Key? key, required this.recipe, this.onTap, this.onDelete})
    : super(key: key);

  final Recipe recipe;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        title: Text(recipe.title),
        subtitle: const Text('Dummy text'),
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
