import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:recipe_capturer/data/recipe_repository.dart';
import 'package:recipe_capturer/domain/recipe.dart';
import 'package:url_launcher/url_launcher.dart';

class NewRecipePage extends StatefulWidget {
  const NewRecipePage({
    super.key,
    required this.title,
    required this.repo,
    this.initialTitle,
    this.initialIngredients,
    this.initialInstructions,
    this.initialRecipe,
    this.initialImagePaths,
    this.initialOcrRawText,
    this.initialSharedLinkText,
    this.initialSourceUrl,
    this.isImportReview = false,
    this.isSharedLinkImport = false,
  });

  final String title;
  final RecipeRepository repo;
  final String? initialTitle;
  final String? initialIngredients;
  final String? initialInstructions;
  final Recipe? initialRecipe;
  final List<String>? initialImagePaths;
  final String? initialOcrRawText;
  final String? initialSharedLinkText;
  final String? initialSourceUrl;
  final bool isImportReview;
  final bool isSharedLinkImport;

  @override
  State<NewRecipePage> createState() => _NewRecipePageState();
}

class _NewRecipePageState extends State<NewRecipePage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _sourceUrlController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();
  final Set<String> _selectedTags = {};

  final List<TextEditingController> _ingredientControllers = [];
  final List<FocusNode> _ingredientFocusNodes = [];

  List<String> _imagePaths = [];
  String _ocrRawText = '';
  String _sharedLinkText = '';

  bool get _isOcrImportMode => widget.isImportReview && _imagePaths.isNotEmpty;
  bool get _isSharedLinkMode =>
      widget.isSharedLinkImport && _sharedLinkText.isNotEmpty;

  static const Map<String, String> _tagLabelsDe = {
    'quick': 'Schnell',
    'savory': 'Herzhaft',
    'dessert': 'Dessert',
    'sweet': 'Süß',
    'breakfast': 'Frühstück',
    'dinner': 'Abendessen',
    'snack': 'Snack',
    'vegetarian': 'Vegetarisch',
  };

  @override
  void initState() {
    super.initState();

    final initialRecipe = widget.initialRecipe;

    if (initialRecipe != null) {
      _titleController.text = initialRecipe.title;
      _sourceUrlController.text = initialRecipe.sourceUrl;
      _instructionsController.text = initialRecipe.instructions;
      _selectedTags.addAll(initialRecipe.tags);
      _imagePaths = [...initialRecipe.imagePaths];

      if (initialRecipe.ingredients.isEmpty) {
        _addIngredientRow();
      } else {
        for (final ingredient in initialRecipe.ingredients) {
          _addIngredientRow(text: ingredient);
        }
        _addIngredientRow();
      }

      return;
    }

    if (widget.initialTitle != null) {
      _titleController.text = widget.initialTitle!;
    }
    if (widget.initialSourceUrl != null) {
      _sourceUrlController.text = widget.initialSourceUrl!;
    }

    if (widget.initialInstructions != null) {
      _instructionsController.text = widget.initialInstructions!;
    }

    _ocrRawText = widget.initialOcrRawText?.trim() ?? '';
    _sharedLinkText = widget.initialSharedLinkText?.trim() ?? '';
    _imagePaths = [...?widget.initialImagePaths];

    final initialLines = (widget.initialIngredients ?? '')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    if (initialLines.isEmpty) {
      _addIngredientRow();
    } else {
      for (final line in initialLines) {
        _addIngredientRow(text: line);
      }
      _addIngredientRow();
    }

    _prefillSourceUrlFromClipboardIfInstagram();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _sourceUrlController.dispose();
    _instructionsController.dispose();

    for (final controller in _ingredientControllers) {
      controller.dispose();
    }
    for (final focusNode in _ingredientFocusNodes) {
      focusNode.dispose();
    }

    super.dispose();
  }

  void _addIngredientRow({String text = ''}) {
    _ingredientControllers.add(TextEditingController(text: text));
    _ingredientFocusNodes.add(FocusNode());
  }

  void _appendRowAndFocus() {
    setState(() {
      _addIngredientRow();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _ingredientFocusNodes.last.requestFocus();
    });
  }

  void _handleIngredientSubmitted(int index) {
    final currentText = _ingredientControllers[index].text.trim();
    final isLastRow = index == _ingredientControllers.length - 1;

    if (currentText.isEmpty) return;

    if (isLastRow) {
      _appendRowAndFocus();
      return;
    }

    _ingredientFocusNodes[index + 1].requestFocus();
  }

  void _removeIngredientRow(int index) {
    final controller = _ingredientControllers.removeAt(index);
    final focusNode = _ingredientFocusNodes.removeAt(index);

    controller.dispose();
    focusNode.dispose();

    if (_ingredientControllers.isEmpty) {
      _addIngredientRow();
    }

    setState(() {});
  }

  void _openImageViewer(int initialIndex) {
    if (_imagePaths.isEmpty) return;

    showDialog<void>(
      context: context,
      builder: (_) => _RecipeImageViewerDialog(
        imagePaths: _imagePaths,
        initialIndex: initialIndex,
      ),
    );
  }

  List<String> _splitOcrLines() {
    return _ocrRawText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  void _applyOcrAsIngredients() {
    final lines = _splitOcrLines();
    if (lines.isEmpty) return;

    for (final controller in _ingredientControllers) {
      controller.dispose();
    }
    for (final focusNode in _ingredientFocusNodes) {
      focusNode.dispose();
    }
    _ingredientControllers.clear();
    _ingredientFocusNodes.clear();

    for (final line in lines) {
      _addIngredientRow(text: line);
    }
    _addIngredientRow();

    setState(() {});
  }

  void _applyOcrAsInstructions() {
    final text = _ocrRawText.trim();
    if (text.isEmpty) return;
    _instructionsController.text = text;
    setState(() {});
  }

  Future<void> _openInstagram() async {
    final appUri = Uri.parse('instagram://app');
    final webUri = Uri.parse('https://www.instagram.com');

    final openedApp = await launchUrl(appUri, mode: LaunchMode.externalApplication);
    if (openedApp) return;

    await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  Future<void> _pasteSourceUrlFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final value = data?.text?.trim() ?? '';
    if (value.isEmpty) return;

    _sourceUrlController.text = value;
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Link eingefügt')));
  }

  Future<void> _prefillSourceUrlFromClipboardIfInstagram() async {
    if (_sourceUrlController.text.trim().isNotEmpty) return;

    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final value = data?.text?.trim() ?? '';
    if (!_isInstagramUrl(value)) return;
    if (!mounted) return;

    setState(() {
      _sourceUrlController.text = value;
    });
  }

  bool _isInstagramUrl(String value) {
    if (value.isEmpty) return false;

    final uri = Uri.tryParse(value);
    final host = uri?.host.toLowerCase() ?? '';
    if (host.isEmpty) return false;

    return host.contains('instagram.com') || host.contains('instagr.am');
  }

  List<String> _collectIngredients() {
    return _ingredientControllers
        .map((controller) => controller.text.trim())
        .where((line) => line.isNotEmpty)
        .toList();
  }

  Widget _buildImportValidationCard() {
    final hasTitle = _titleController.text.trim().isNotEmpty;
    final hasIngredients = _collectIngredients().isNotEmpty;
    final hasInstructions = _instructionsController.text.trim().isNotEmpty;

    Widget row(bool ok, String label) {
      return Row(
        children: [
          Icon(
            ok ? Icons.check_circle_outline : Icons.error_outline,
            size: 18,
            color: ok ? Colors.green.shade700 : Colors.orange.shade700,
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      );
    }

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vor dem Speichern prüfen',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            row(hasTitle, 'Titel vorhanden'),
            const SizedBox(height: 6),
            row(hasIngredients, 'Mindestens eine Zutat'),
            const SizedBox(height: 6),
            row(hasInstructions, 'Zubereitung vorhanden'),
          ],
        ),
      ),
    );
  }

  String _titleConfidenceLabel() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return 'Niedrig';
    if (title.length >= 8 && title.length <= 50) return 'Hoch';
    return 'Mittel';
  }

  Color _confidenceColor(String level) {
    switch (level) {
      case 'Hoch':
        return Colors.green.shade700;
      case 'Mittel':
        return Colors.orange.shade700;
      default:
        return Colors.red.shade700;
    }
  }

  Widget _buildConfidenceChip(String label, String value) {
    final levelColor = _confidenceColor(value);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: levelColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(color: levelColor, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildMetricChip(String label, String value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildImportConfidenceCard() {
    final ingredientsCount = _collectIngredients().length;
    final instructionsLength = _instructionsController.text.trim().length;
    final titleConfidence = _titleConfidenceLabel();

    final ingredientsLabel = ingredientsCount == 0
        ? '0 Zeilen'
        : '$ingredientsCount Zeilen';
    final instructionsLabel = '$instructionsLength Zeichen';

    final likelyWeak =
        ingredientsCount == 0 ||
        instructionsLength < 60 ||
        titleConfidence == 'Niedrig';

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'OCR-Qualität (schnelleinschätzung)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildConfidenceChip('Titel', titleConfidence),
                _buildMetricChip('Zutaten', ingredientsLabel),
                _buildMetricChip('Zubereitung', instructionsLabel),
              ],
            ),
            if (likelyWeak) ...[
              const SizedBox(height: 10),
              Text(
                'Achtung: OCR wirkt unvollständig. Bitte Quellbilder und Rohtext prüfen.',
                style: TextStyle(
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSharedLinkCard() {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.link),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Instagram-Link erkannt. Ergänze jetzt Titel, Zutaten und Zubereitung.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).colorScheme.surface,
              ),
              child: SelectableText(_sharedLinkText),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: _sharedLinkText),
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link kopiert')),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Link kopieren'),
                  ),
                  FilledButton.icon(
                    onPressed: _importScreenshotsFromSharedLink,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Screenshots importieren'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Hinweis: Ein geteilter Instagram-Link enthält meist keinen Rezepttext. Für automatische Extraktion bitte Screenshots importieren.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _importScreenshotsFromSharedLink() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isEmpty) return;

    final paths = images.map((e) => e.path).toList();

    if (!mounted) return;
    final imported = await context.push<bool>(
      '/import',
      extra: {'imagePaths': paths, 'sharedText': _sharedLinkText},
    );

    if (!mounted) return;
    if (imported == true) {
      context.pop(true);
    }
  }

  Future<void> _save() async {
    try {
      final initialRecipe = widget.initialRecipe;

      if (initialRecipe == null) {
        final recipe = Recipe.create(
          _titleController.text,
          ingredients: _collectIngredients(),
          tags: _selectedTags.toList(),
          instructions: _instructionsController.text,
          imagePaths: _imagePaths,
          sourceUrl: _sourceUrlController.text.trim(),
        );

        await widget.repo.add(recipe);
      } else {
        final updatedRecipe = initialRecipe.copyWith(
          title: _titleController.text.trim(),
          ingredients: _collectIngredients(),
          tags: _selectedTags.toList(),
          instructions: _instructionsController.text.trim(),
          imagePaths: _imagePaths,
          sourceUrl: _sourceUrlController.text.trim(),
        );

        await widget.repo.update(updatedRecipe);
      }

      if (!mounted) return;
      context.pop(true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rezepttitel kann nicht leer sein!')),
      );
    }
  }

  Widget _buildImagePreviewSection() {
    if (_imagePaths.isEmpty) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _isOcrImportMode ? 'Quellbilder' : 'Bilder',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (_isOcrImportMode) ...[
              const SizedBox(height: 4),
              Text(
                'Diese Bilder bleiben die Quelle. Passe die Felder unten nach Bedarf an.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _imagePaths.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final path = _imagePaths[index];

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
                            child: Center(
                              child: Icon(Icons.broken_image_outlined),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tagChips = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _tagLabelsDe.entries.map((e) {
        final key = e.key;
        final label = e.value;
        final selected = _selectedTags.contains(key);

        return FilterChip(
          label: Text(label),
          selected: selected,
          onSelected: (v) {
            setState(() {
              if (v) {
                _selectedTags.add(key);
              } else {
                _selectedTags.remove(key);
              }
            });
          },
        );
      }).toList(),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _save,
            tooltip: 'Speichern',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          if (_isOcrImportMode) ...[
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.edit_note_outlined),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'OCR hat diese Felder vorbefüllt. Bitte prüfe Titel, Zutaten und Zubereitung vor dem Speichern.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_ocrRawText.isNotEmpty) ...[
              ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                title: const Text('OCR-Rohtext'),
                subtitle: const Text(
                  'Quelle prüfen und bei Bedarf direkt übernehmen',
                ),
                childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Theme.of(context).colorScheme.surface,
                    ),
                    child: SelectableText(_ocrRawText),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _applyOcrAsIngredients,
                        icon: const Icon(Icons.format_list_bulleted),
                        label: const Text('In Zutaten aufteilen'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _applyOcrAsInstructions,
                        icon: const Icon(Icons.subject),
                        label: const Text('Als Zubereitung übernehmen'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            _buildImportValidationCard(),
            const SizedBox(height: 12),
            _buildImportConfidenceCard(),
            const SizedBox(height: 12),
          ],
          if (_isSharedLinkMode) ...[
            _buildSharedLinkCard(),
            const SizedBox(height: 12),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: _isOcrImportMode
                          ? 'Titel (OCR-Vorschlag)'
                          : 'Titel',
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _sourceUrlController,
                    decoration: InputDecoration(
                      labelText: 'Quelle (Link optional)',
                      hintText: 'https://...',
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 92,
                        maxWidth: 120,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: _pasteSourceUrlFromClipboard,
                            tooltip: 'Aus Zwischenablage einfügen',
                            icon: const Icon(Icons.content_paste_go_outlined),
                          ),
                          IconButton(
                            onPressed: _openInstagram,
                            tooltip: 'Instagram öffnen',
                            icon: const Icon(Icons.open_in_new),
                          ),
                        ],
                      ),
                    ),
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.next,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildImagePreviewSection(),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tags',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  tagChips,
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Zutaten',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  if (_isOcrImportMode) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Als OCR-Vorschlag erkannt. Ergänze oder korrigiere bei Bedarf.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  ...List.generate(_ingredientControllers.length, (index) {
                    final isLast = index == _ingredientControllers.length - 1;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _ingredientControllers[index],
                              focusNode: _ingredientFocusNodes[index],
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) =>
                                  _handleIngredientSubmitted(index),
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                hintText: isLast
                                    ? 'Zutat eingeben und Enter drücken'
                                    : 'Zutat ${index + 1}',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: () => _removeIngredientRow(index),
                            icon: const Icon(Icons.delete_outline),
                            tooltip: 'Zutat entfernen',
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Zubereitung',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  if (_isOcrImportMode) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Automatisch erkannt. Formuliere und strukturiere den Ablauf nach Bedarf.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ] else if (_isSharedLinkMode) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Der geteilte Link wurde als Quelle übernommen. Ergänze hier den eigentlichen Ablauf.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: _instructionsController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      hintText: 'Zubereitung eingeben',
                      alignLabelWithHint: true,
                    ),
                    minLines: 6,
                    maxLines: 12,
                    keyboardType: TextInputType.multiline,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
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
