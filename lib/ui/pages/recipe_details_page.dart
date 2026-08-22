import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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
  final Set<int> _checkedIngredients = <int>{};
  final Set<int> _checkedSteps = <int>{};

  bool get _hasMissingIngredients => recipe.ingredients.isEmpty;
  bool get _hasMissingInstructions => recipe.instructions.trim().length < 40;

  List<String> _reviewNotes() {
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

  void _showReviewDetailsSheet() {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final notes = _reviewNotes();

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

  Future<void> _updateRecipe(Recipe updatedRecipe) async {
    await widget.repo.update(updatedRecipe);
    if (!mounted) return;
    setState(() => recipe = updatedRecipe);
  }

  Future<void> _editIngredientsInline() async {
    final controller = TextEditingController(
      text: recipe.ingredients.join('\n'),
    );
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Zutaten', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 6,
                maxLines: 10,
                decoration: const InputDecoration(
                  hintText: 'Eine Zutat pro Zeile',
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Speichern'),
              ),
            ],
          ),
        );
      },
    );

    if (saved == true) {
      final ingredients = controller.text
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      await _updateRecipe(recipe.copyWith(ingredients: ingredients));
    }
    controller.dispose();
  }

  Future<void> _editInstructionsInline() async {
    final controller = TextEditingController(text: recipe.instructions.trim());
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Zubereitung',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 7,
                maxLines: 12,
                decoration: const InputDecoration(
                  hintText: 'Schritte oder Fließtext',
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Speichern'),
              ),
            ],
          ),
        );
      },
    );

    if (saved == true) {
      await _updateRecipe(
        recipe.copyWith(instructions: controller.text.trim()),
      );
    }
    controller.dispose();
  }

  Future<void> _refreshRecipe() async {
    final refreshed = await widget.repo.getAll();
    final updated = refreshed.where((r) => r.id == recipe.id).firstOrNull;
    if (!mounted) return;
    if (updated != null) {
      setState(() => recipe = updated);
    }
  }

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

  void _toggleIngredient(int index) {
    setState(() {
      if (!_checkedIngredients.add(index)) {
        _checkedIngredients.remove(index);
      }
    });
  }

  void _toggleStep(int index) {
    setState(() {
      if (!_checkedSteps.add(index)) {
        _checkedSteps.remove(index);
      }
    });
  }

  Future<void> _editRecipe() async {
    final saved = await context.push<bool>('/edit', extra: recipe);

    if (!context.mounted) return;

    if (saved == true) {
      await _refreshRecipe();
    }
  }

  Future<void> _addImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isEmpty) return;

    final updatedRecipe = recipe.copyWith(
      imagePaths: [...recipe.imagePaths, ...picked.map((e) => e.path)],
    );

    await widget.repo.update(updatedRecipe);
    await _refreshRecipe();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${picked.length} Bild(er) hinzugefügt')),
    );
  }

  Future<void> _handleMenuAction(String value) async {
    if (value == 'edit') {
      await _editRecipe();
      return;
    }
    if (value == 'add_images') {
      await _addImages();
      return;
    }
    if (value == 'delete') {
      await _confirmAndDelete();
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

  void _openImageViewer(int initialIndex) {
    if (recipe.imagePaths.isEmpty) return;

    showDialog<void>(
      context: context,
      builder: (_) => _RecipeImageViewerDialog(
        imagePaths: recipe.imagePaths,
        initialIndex: initialIndex,
      ),
    );
  }

  Widget _buildMainImage() {
    final hasImages = recipe.imagePaths.isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Material(
            borderRadius: BorderRadius.circular(28),
            clipBehavior: Clip.antiAlias,
            child: hasImages
                ? InkWell(
                    onTap: () => _openImageViewer(0),
                    child: Image.file(
                      File(recipe.imagePaths.first),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Image.asset(
                        'assets/recipe_placeholder.jpg',
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                : Image.asset(
                    'assets/recipe_placeholder.jpg',
                    fit: BoxFit.cover,
                  ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.02),
                  Colors.black.withValues(alpha: 0.08),
                  Colors.black.withValues(alpha: 0.34),
                ],
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Material(
              color: colorScheme.surface.withValues(alpha: 0.9),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
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

  Widget _buildImageGallery() {
    if (recipe.imagePaths.length <= 1) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text('Originalbilder', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: recipe.imagePaths.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final path = recipe.imagePaths[index];

              return GestureDetector(
                onTap: () => _openImageViewer(index),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
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
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  List<String> _instructionSteps() {
    return recipe.instructions
        .split(RegExp(r'\n{2,}|\n'))
        .map((step) => step.trim())
        .where((step) => step.isNotEmpty)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dateLabel = dateLabelDe(recipe.createdAt, now);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final steps = _instructionSteps();
    final needsReview =
        recipe.ingredients.isEmpty || recipe.instructions.trim().length < 40;

    return Scaffold(
      appBar: AppBar(
        title: Text(recipe.title),
        actions: [
          PopupMenuButton<String>(
            onSelected: _handleMenuAction,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Bearbeiten')),
              PopupMenuItem(
                value: 'add_images',
                child: Text('Bilder hinzufügen'),
              ),
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
          const SizedBox(height: 14),
          if (needsReview) ...[
            _buildSectionCard(
              title: 'Fehlende Angaben',
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  if (_hasMissingIngredients)
                    OutlinedButton.icon(
                      onPressed: _editIngredientsInline,
                      icon: const Icon(Icons.format_list_bulleted_rounded),
                      label: const Text('Zutaten ergänzen'),
                    ),
                  if (_hasMissingInstructions)
                    OutlinedButton.icon(
                      onPressed: _editInstructionsInline,
                      icon: const Icon(Icons.notes_rounded),
                      label: const Text('Zubereitung ergänzen'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(alpha: 0.75),
              ),
            ),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _InfoPill(label: '${recipe.ingredients.length} Zutaten'),
                _InfoPill(label: '${StringsDe.addedLabel}: $dateLabel'),
                if (needsReview)
                  _InfoPill(
                    label: 'Noch prüfen',
                    tone: colorScheme.tertiaryContainer,
                    textColor: colorScheme.onTertiaryContainer,
                    onTap: _showReviewDetailsSheet,
                  ),
              ],
            ),
          ),
          if (recipe.tags.isNotEmpty) ...[
            const SizedBox(height: 16),
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
          ],
          const SizedBox(height: 16),
          _buildSectionCard(
            title: 'Zutaten',
            child: recipe.ingredients.isEmpty
                ? Text(
                    StringsDe.noIngredients,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(recipe.ingredients.length, (index) {
                      final ingredient = recipe.ingredients[index];
                      final isChecked = _checkedIngredients.contains(index);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          onTap: () => _toggleIngredient(index),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isChecked
                                  ? colorScheme.surfaceContainerHigh
                                  : colorScheme.surfaceContainerLow,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: colorScheme.outlineVariant.withValues(
                                  alpha: 0.45,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isChecked
                                      ? Icons.check_circle
                                      : Icons.radio_button_unchecked,
                                  size: 20,
                                  color: isChecked
                                      ? colorScheme.primary
                                      : colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    ingredient,
                                    style: textTheme.bodyLarge?.copyWith(
                                      height: 1.35,
                                      decoration: isChecked
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: isChecked
                                          ? colorScheme.onSurfaceVariant
                                          : colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
          ),
          if (steps.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'Zubereitung',
              child: Column(
                children: List.generate(steps.length, (index) {
                  final isChecked = _checkedSteps.contains(index);
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == steps.length - 1 ? 0 : 14,
                    ),
                    child: InkWell(
                      onTap: () => _toggleStep(index),
                      borderRadius: BorderRadius.circular(18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isChecked
                                  ? colorScheme.primary
                                  : colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: textTheme.labelMedium?.copyWith(
                                color: isChecked
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                steps[index],
                                style: textTheme.bodyLarge?.copyWith(
                                  height: 1.5,
                                  decoration: isChecked
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: isChecked
                                      ? colorScheme.onSurfaceVariant
                                      : colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
          if (recipe.ingredients.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: FilledButton.icon(
                onPressed: _editIngredientsInline,
                icon: const Icon(Icons.format_list_bulleted_rounded),
                label: const Text('Zutaten hinzufügen'),
              ),
            ),
          if (recipe.instructions.trim().isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: FilledButton.icon(
                onPressed: _editInstructionsInline,
                icon: const Icon(Icons.notes_rounded),
                label: const Text('Zubereitung hinzufügen'),
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label, this.tone, this.textColor, this.onTap});

  final String label;
  final Color? tone;
  final Color? textColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: tone ?? colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: textColor ?? colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _RecipeImageViewerDialog extends StatefulWidget {
  const _RecipeImageViewerDialog({
    required this.imagePaths,
    required this.initialIndex,
  });

  final List<String> imagePaths;
  final int initialIndex;

  @override
  State<_RecipeImageViewerDialog> createState() =>
      _RecipeImageViewerDialogState();
}

class _RecipeImageViewerDialogState extends State<_RecipeImageViewerDialog> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text('${_currentIndex + 1}/${widget.imagePaths.length}'),
        ),
        body: PageView.builder(
          controller: _pageController,
          itemCount: widget.imagePaths.length,
          onPageChanged: (index) => setState(() => _currentIndex = index),
          itemBuilder: (context, index) {
            final path = widget.imagePaths[index];
            return InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Image.file(
                  File(path),
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.broken_image_outlined,
                    size: 44,
                    color: Colors.white70,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
