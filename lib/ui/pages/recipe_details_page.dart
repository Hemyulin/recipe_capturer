import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:recipe_capturer/data/recipe_repository.dart';
import 'package:recipe_capturer/domain/recipe.dart';
import 'package:recipe_capturer/ui/formatters/date_label_de.dart';
import 'package:recipe_capturer/ui/formatters/strings_de.dart';
import 'package:recipe_capturer/ui/formatters/tag_label_de.dart';
import 'package:url_launcher/url_launcher.dart';

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

  Future<void> _refreshRecipe() async {
    final refreshed = await widget.repo.getAll();
    final updated = refreshed.where((r) => r.id == recipe.id).firstOrNull;
    if (!mounted) return;
    if (updated != null) {
      setState(() => recipe = updated);
    }
  }

  Future<void> _openSourceUrl() async {
    final raw = recipe.sourceUrl.trim();
    if (raw.isEmpty) return;

    final uri = Uri.tryParse(raw);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Ungültiger Link')));
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link konnte nicht geöffnet werden')),
      );
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

              return GestureDetector(
                onTap: () => _openImageViewer(index),
                child: ClipRRect(
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
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.schedule_outlined,
                  size: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    meta,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (recipe.tags.isNotEmpty)
            _buildSectionCard(
              title: 'Tags',
              child: Wrap(
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
            ),
          if (recipe.tags.isNotEmpty) const SizedBox(height: 16),
          if (recipe.sourceUrl.trim().isNotEmpty) ...[
            _buildSectionCard(
              title: 'Quelle',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText(recipe.sourceUrl.trim()),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _openSourceUrl,
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('Link öffnen'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: recipe.sourceUrl.trim()),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Link kopiert')),
                          );
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text('Link kopieren'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
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
                    children: recipe.ingredients
                        .map(
                          (ingredient) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              '• $ingredient',
                              style: textTheme.bodyMedium?.copyWith(
                                height: 1.35,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
          if (recipe.instructions.trim().isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildSectionCard(
              title: 'Zubereitung',
              child: Text(
                recipe.instructions,
                style: textTheme.bodyMedium?.copyWith(height: 1.45),
              ),
            ),
          ],
          const SizedBox(height: 20),
        ],
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
