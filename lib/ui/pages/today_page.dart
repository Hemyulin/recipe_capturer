import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:recipe_capturer/data/recipe_repository.dart';
import 'package:recipe_capturer/domain/recipe.dart';
import 'package:recipe_capturer/ui/widgets/recipe_image.dart';

class TodayPage extends StatefulWidget {
  const TodayPage({super.key, required this.repo});

  final RecipeRepository repo;

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  List<Recipe> _recipes = [];
  final Map<String, String?> _mealRecipeIds = {};

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    final recipes = await widget.repo.getAll();
    if (!mounted) return;
    setState(() => _recipes = recipes);
  }

  Recipe? _recipeById(String? id) {
    if (id == null) return null;
    for (final recipe in _recipes) {
      if (recipe.id == id) return recipe;
    }
    return null;
  }

  Recipe? _recipeForTag(String tag) {
    for (final recipe in _recipes) {
      if (recipe.tags.contains(tag)) return recipe;
    }
    return null;
  }

  Recipe? _recipeForSlot(String slotId, String fallbackTag) {
    if (_mealRecipeIds.containsKey(slotId)) {
      return _recipeById(_mealRecipeIds[slotId]);
    }
    return _recipeForTag(fallbackTag);
  }

  Future<void> _openRecipe(Recipe? recipe) async {
    if (recipe == null) return;
    await context.push('/details', extra: recipe);
    await _loadRecipes();
  }

  Future<void> _chooseRecipe(String slotId) async {
    if (_recipes.isEmpty) return;

    final selected = await showModalBottomSheet<Recipe>(
      context: context,
      showDragHandle: true,
      builder: (context) => _RecipePickerSheet(recipes: _recipes),
    );
    if (selected == null || !mounted) return;

    setState(() => _mealRecipeIds[slotId] = selected.id);
  }

  void _clearRecipe(String slotId) {
    setState(() => _mealRecipeIds[slotId] = null);
  }

  @override
  Widget build(BuildContext context) {
    final breakfast = _recipeForSlot('breakfast', 'breakfast');
    final lunch = _recipeForSlot('lunch', 'lunch');
    final dinner = _recipeForSlot('dinner', 'dinner');

    return Scaffold(
      appBar: AppBar(title: const Text('Heute')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Text(
            'Was essen wir heute?',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 14),
          _MealSlotCard(
            title: 'Frühstück',
            time: '07:30',
            recipe: breakfast,
            isRecurring: breakfast != null,
            onTap: breakfast == null
                ? () => _chooseRecipe('breakfast')
                : () => _openRecipe(breakfast),
            onChange: () => _chooseRecipe('breakfast'),
            onClear: () => _clearRecipe('breakfast'),
          ),
          const SizedBox(height: 12),
          _MealSlotCard(
            title: 'Mittagessen',
            time: '12:30',
            recipe: lunch,
            onTap: lunch == null
                ? () => _chooseRecipe('lunch')
                : () => _openRecipe(lunch),
            onChange: () => _chooseRecipe('lunch'),
            onClear: () => _clearRecipe('lunch'),
          ),
          const SizedBox(height: 12),
          _MealSlotCard(
            title: 'Abendessen',
            time: '18:30',
            recipe: dinner,
            onTap: dinner == null
                ? () => _chooseRecipe('dinner')
                : () => _openRecipe(dinner),
            onChange: () => _chooseRecipe('dinner'),
            onClear: () => _clearRecipe('dinner'),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Heute vorbereiten',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Noch keine Vorbereitung geplant.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MealSlotCard extends StatelessWidget {
  const _MealSlotCard({
    required this.title,
    required this.time,
    this.recipe,
    this.isRecurring = false,
    this.onTap,
    this.onChange,
    this.onClear,
  });

  final String title;
  final String time;
  final Recipe? recipe;
  final bool isRecurring;
  final VoidCallback? onTap;
  final VoidCallback? onChange;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final imagePath = recipe?.mainImagePath;

    final card = Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 86,
                  height: 86,
                  child: imagePath == null
                      ? ColoredBox(
                          color: colorScheme.surfaceContainerHigh,
                          child: Icon(
                            Icons.restaurant_menu_outlined,
                            color: colorScheme.primary,
                          ),
                        )
                      : RecipeImage(path: imagePath),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      time,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      recipe?.title ?? 'Nichts geplant',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (isRecurring)
                          const _MealBadge(
                            icon: Icons.lock_outline,
                            label: 'wiederkehrend',
                          ),
                        if (recipe?.totalTimeMinutes != null)
                          _MealBadge(
                            icon: Icons.schedule_outlined,
                            label: '${recipe!.totalTimeMinutes} min',
                          ),
                        if (recipe == null)
                          const _MealBadge(
                            icon: Icons.add_rounded,
                            label: 'Planen',
                          ),
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

    if (recipe == null) return card;

    return Dismissible(
      key: ValueKey('${title}_${recipe!.id}'),
      direction: DismissDirection.horizontal,
      background: const _SwipeActionBackground(
        alignment: Alignment.centerLeft,
        icon: Icons.swap_horiz_rounded,
        label: 'Ändern',
      ),
      secondaryBackground: const _SwipeActionBackground(
        alignment: Alignment.centerRight,
        icon: Icons.delete_outline,
        label: 'Entfernen',
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onChange?.call();
          return false;
        }

        onClear?.call();
        return false;
      },
      child: card,
    );
  }
}

class _RecipePickerSheet extends StatelessWidget {
  const _RecipePickerSheet({required this.recipes});

  final List<Recipe> recipes;

  @override
  Widget build(BuildContext context) {
    final sortedRecipes = [...recipes]
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));

    return SafeArea(
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: sortedRecipes.length + 1,
        separatorBuilder: (_, index) =>
            index == 0 ? const SizedBox(height: 8) : const Divider(height: 1),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Rezept auswählen',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            );
          }

          final recipe = sortedRecipes[index - 1];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 56,
                height: 56,
                child: RecipeImage(path: recipe.mainImagePath),
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
            onTap: () => Navigator.of(context).pop(recipe),
          );
        },
      ),
    );
  }
}

class _SwipeActionBackground extends StatelessWidget {
  const _SwipeActionBackground({
    required this.alignment,
    required this.icon,
    required this.label,
  });

  final Alignment alignment;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isStart = alignment == Alignment.centerLeft;

    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      decoration: BoxDecoration(
        color: isStart
            ? colorScheme.primaryContainer
            : colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isStart) Text(label),
          if (!isStart) const SizedBox(width: 8),
          Icon(icon),
          if (isStart) const SizedBox(width: 8),
          if (isStart) Text(label),
        ],
      ),
    );
  }
}

class _MealBadge extends StatelessWidget {
  const _MealBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colorScheme.primary),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}
