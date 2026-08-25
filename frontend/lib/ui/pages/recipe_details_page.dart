import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cookbuk/data/meal_plan_repository.dart';
import 'package:cookbuk/data/recipe_repository.dart';
import 'package:cookbuk/domain/recipe.dart';
import 'package:cookbuk/ui/formatters/tag_label_de.dart';
import 'package:cookbuk/ui/widgets/backend_connection_icon.dart';
import 'package:cookbuk/ui/widgets/recipe_image.dart';

class RecipeDetailsPage extends StatefulWidget {
  const RecipeDetailsPage({
    super.key,
    required this.recipe,
    required this.repo,
    this.mealPlanRepo,
  });

  final Recipe recipe;
  final RecipeRepository repo;
  final MealPlanRepository? mealPlanRepo;

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

  Future<void> _markReviewed() async {
    final next = recipe.copyWith(
      tags: recipe.tags.where((tag) => tag != 'needs_review').toList(),
    );
    setState(() => recipe = next);
    await widget.repo.update(next);
  }

  Future<Recipe?> _setMainImage(int index) async {
    if (index <= 0 || index >= recipe.imagePaths.length) return recipe;

    final reorderedImages = [
      recipe.imagePaths[index],
      for (var i = 0; i < recipe.imagePaths.length; i++)
        if (i != index) recipe.imagePaths[i],
    ];
    final previous = recipe;
    final next = recipe.copyWith(imagePaths: reorderedImages);

    setState(() => recipe = next);
    try {
      final updated = await widget.repo.update(next);
      if (!mounted) return updated;
      setState(() => recipe = updated);
      return updated;
    } catch (_) {
      if (!mounted) return null;
      setState(() => recipe = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hauptbild konnte nicht geändert werden.'),
        ),
      );
      return null;
    }
  }

  Future<void> _editRecipe() async {
    final saved = await context.push<bool>('/edit', extra: recipe);
    if (!mounted) return;
    if (saved == true) await _refreshRecipe();
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

  Widget _buildImageGallery(ColorScheme colorScheme) {
    final imagePaths = recipe.imagePaths;
    final imagePath = recipe.mainImagePath;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 10,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Material(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: imagePaths.isEmpty
                      ? null
                      : () => _openImageViewer(initialIndex: 0),
                  child: RecipeImage(
                    path: imagePath,
                    placeholderSeed: recipe.id,
                  ),
                ),
              ),
              if (imagePaths.length > 1)
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: _ImageCountBadge(count: imagePaths.length),
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
                      recipe.isFavorite
                          ? Icons.favorite
                          : Icons.favorite_border,
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
        ),
        if (imagePaths.length > 1) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: imagePaths.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => _ImageThumb(
                path: imagePaths[index],
                isMain: index == 0,
                onTap: () => _openImageViewer(initialIndex: index),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openImageViewer({required int initialIndex}) async {
    if (recipe.imagePaths.isEmpty) return;
    final updatedRecipe = await Navigator.of(context).push<Recipe>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _RecipeImageViewer(
          title: recipe.title,
          imagePaths: recipe.imagePaths,
          initialIndex: initialIndex,
          placeholderSeed: recipe.id,
          onSetMainImage: _setMainImage,
        ),
      ),
    );
    if (!mounted || updatedRecipe == null) return;
    setState(() => recipe = updatedRecipe);
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
          if (widget.mealPlanRepo != null)
            BackendConnectionIcon(mealPlanRepo: widget.mealPlanRepo!),
          IconButton(
            onPressed: _editRecipe,
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Bearbeiten',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'reviewed') _markReviewed();
              if (value == 'stats') _showStats();
              if (value == 'delete') _confirmAndDelete();
            },
            itemBuilder: (context) => [
              if (recipe.tags.contains('needs_review'))
                const PopupMenuItem(
                  value: 'reviewed',
                  child: Text('Als geprüft markieren'),
                ),
              const PopupMenuItem(value: 'stats', child: Text('Statistiken')),
              const PopupMenuItem(value: 'delete', child: Text('Löschen')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          _buildImageGallery(colorScheme),
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
          if (recipe.preparationTasks.isNotEmpty) ...[
            _buildSection(
              title: 'Vorbereitung',
              child: Column(
                children: List.generate(recipe.preparationTasks.length, (
                  index,
                ) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.hourglass_bottom_rounded,
                      color: colorScheme.primary,
                    ),
                    title: Text(recipe.preparationTasks[index]),
                  );
                }),
              ),
            ),
            const SizedBox(height: 14),
          ],
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

class _ImageCountBadge extends StatelessWidget {
  const _ImageCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.photo_library_outlined,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageThumb extends StatelessWidget {
  const _ImageThumb({
    required this.path,
    required this.isMain,
    required this.onTap,
  });

  final String path;
  final bool isMain;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 86,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isMain ? colorScheme.primary : colorScheme.outlineVariant,
            width: isMain ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            RecipeImage(path: path, placeholderSeed: path),
            if (isMain)
              Positioned(
                left: 4,
                bottom: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    child: Text(
                      'Hauptbild',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RecipeImageViewer extends StatefulWidget {
  const _RecipeImageViewer({
    required this.title,
    required this.imagePaths,
    required this.initialIndex,
    required this.placeholderSeed,
    required this.onSetMainImage,
  });

  final String title;
  final List<String> imagePaths;
  final int initialIndex;
  final String placeholderSeed;
  final Future<Recipe?> Function(int index) onSetMainImage;

  @override
  State<_RecipeImageViewer> createState() => _RecipeImageViewerState();
}

class _RecipeImageViewerState extends State<_RecipeImageViewer> {
  late final PageController _pageController;
  late int _index;
  bool _isSavingMainImage = false;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.imagePaths.length - 1);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canSetMain =
        widget.imagePaths.length > 1 && _index != 0 && !_isSavingMainImage;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          if (widget.imagePaths.length > 1)
            TextButton.icon(
              onPressed: canSetMain ? _setCurrentAsMain : null,
              icon: _isSavingMainImage
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.star_outline_rounded),
              label: const Text('Hauptbild'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
        ],
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.imagePaths.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: RecipeImage(
                  path: widget.imagePaths[index],
                  fit: BoxFit.contain,
                  placeholderSeed: widget.placeholderSeed,
                ),
              ),
            ),
          ),
          if (widget.imagePaths.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 18,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ImageViewerDots(
                      count: widget.imagePaths.length,
                      activeIndex: _index,
                    ),
                    const SizedBox(height: 10),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.58),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        child: Text(
                          '${_index + 1}/${widget.imagePaths.length}',
                          style: Theme.of(
                            context,
                          ).textTheme.labelLarge?.copyWith(color: Colors.white),
                        ),
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

  Future<void> _setCurrentAsMain() async {
    setState(() => _isSavingMainImage = true);
    final updatedRecipe = await widget.onSetMainImage(_index);
    if (!mounted) return;
    setState(() => _isSavingMainImage = false);
    if (updatedRecipe == null) return;
    Navigator.of(context).pop(updatedRecipe);
  }
}

class _ImageViewerDots extends StatelessWidget {
  const _ImageViewerDots({required this.count, required this.activeIndex});

  final int count;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: [
        for (var index = 0; index < count; index++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: index == activeIndex ? 18 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: index == activeIndex
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.44),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
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
