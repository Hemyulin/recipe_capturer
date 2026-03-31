import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class ImportRecipePage extends StatefulWidget {
  const ImportRecipePage({
    super.key,
    required this.imagePaths,
    this.sharedText,
    this.pickImagesFirst = false,
  });

  final List<String> imagePaths;
  final String? sharedText;
  final bool pickImagesFirst;

  @override
  State<ImportRecipePage> createState() => _ImportRecipePageState();
}

class _ImportRecipePageState extends State<ImportRecipePage> {
  List<String> _imagePaths = [];
  String _recognizedText = '';
  bool _isRecognizing = false;
  String? _errorMessage;
  bool _didStartFlow = false;
  static final RegExp _urlPattern = RegExp(r'https?://\S+');

  @override
  void initState() {
    super.initState();
    _imagePaths = [...widget.imagePaths];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.pickImagesFirst && _imagePaths.isEmpty) {
        _pickImagesAndImport();
      } else {
        _runImportFlow();
      }
    });
  }

  bool _isBlockedLine(String line) {
    final lower = line.toLowerCase().trim();

    const blockedFragments = [
      'publicaciones',
      'gefällt',
      'ver traducción',
      'folgen',
      'follow',
      'instagram',
      'reels',
      'comments',
      'likes',
      'antworten',
      'antwort',
      'audio original',
    ];

    return blockedFragments.any(lower.contains);
  }

  bool _isLikelyNoiseLine(String line) {
    final lower = line.toLowerCase().trim();
    if (lower.isEmpty) {
      return true;
    }
    if (_isBlockedLine(lower)) {
      return true;
    }
    if (RegExp(r'^\d{1,2}:\d{2}\s*[o0]?$').hasMatch(lower)) {
      return true;
    }
    if (lower == 'publicaciones' || lower == 'seguir') {
      return true;
    }
    return false;
  }

  String _normalizeRecipeLine(String line) {
    var normalized = line.trim();
    normalized = normalized.replaceAllMapped(
      RegExp(r'^% ?(tl|el)\b', caseSensitive: false),
      (m) => '1/2 ${m[1]!.toUpperCase()}',
    );
    normalized = normalized.replaceAllMapped(
      RegExp(r'^(\d)([A-Za-zÄÖÜäöü])'),
      (m) => '${m[1]} ${m[2]}',
    );
    return normalized;
  }

  bool _isIngredientHeader(String line) {
    final lower = line.toLowerCase().trim();
    return lower.startsWith('zutaten') ||
        lower.startsWith('topping') ||
        lower.startsWith('teig');
  }

  bool _isInstructionsHeader(String line) {
    final lower = line.toLowerCase().trim();
    return lower.startsWith('zubereitung') ||
        lower.startsWith('zubereiten') ||
        lower.startsWith('zubereitung:');
  }

  bool _isMetaLine(String line) {
    final lower = line.toLowerCase().trim();
    return lower.contains('portionen') ||
        lower.contains('form ') ||
        lower.startsWith('ca.') && lower.contains('portionen');
  }

  bool _looksLikeIngredientLine(String line) {
    final lower = line.toLowerCase().trim();
    if (lower.isEmpty) return false;
    if (_isIngredientHeader(lower) || _isInstructionsHeader(lower)) {
      return false;
    }
    if (_isMetaLine(lower) || _isLikelyInstructionLine(lower)) return false;

    final startsWithQuantity = RegExp(
      r'^([•\-]\s*)?((\d+([.,]\d+)?)|(\d+/\d+)|[¼½¾]|ca\.)',
      caseSensitive: false,
    ).hasMatch(lower);
    final hasUnit = RegExp(
      r'\b(g|kg|mg|ml|l|tl|el|prise|esslöffel|teelöffel|cup|cups)\b',
      caseSensitive: false,
    ).hasMatch(line);
    final looksShortEnough = line.length <= 90;

    return looksShortEnough && (startsWithQuantity || hasUnit);
  }

  bool _isLikelyInstructionLine(String line) {
    final lower = line.toLowerCase().trim();
    if (lower.length < 24) return false;

    const instructionMarkers = [
      'backofen',
      'verrühren',
      'aufkochen',
      'ziehen lassen',
      'pürieren',
      'vermengen',
      'geben',
      'kaltstellen',
      'vorheizen',
      'anschließend',
      'für die',
      'wenn es',
      'dann',
    ];

    return instructionMarkers.any(lower.contains);
  }

  bool _looksLikeTitleCandidate(String line) {
    final lower = line.toLowerCase().trim();
    if (lower.length < 5 || lower.length > 70) return false;
    if (_isIngredientHeader(lower) || _isInstructionsHeader(lower)) {
      return false;
    }
    if (_isMetaLine(lower) || _isLikelyInstructionLine(lower)) return false;
    if (RegExp(r'^\d{1,2}:\d{2}').hasMatch(lower)) return false;
    if (RegExp(r'^\d').hasMatch(lower)) return false;
    return RegExp(r'[A-Za-zÄÖÜäöü]').hasMatch(lower);
  }

  List<String> _mergeWrappedLines(List<String> lines) {
    if (lines.isEmpty) return lines;

    final merged = <String>[];
    for (final line in lines) {
      if (merged.isEmpty) {
        merged.add(line);
        continue;
      }

      final previous = merged.last;
      final shouldMergeBrokenWord =
          RegExp(r'[a-zäöü]$').hasMatch(previous) &&
          RegExp(r'^[a-zäöü]').hasMatch(line);
      final shouldMergeParen = previous.endsWith('(');

      if (shouldMergeBrokenWord || shouldMergeParen) {
        merged[merged.length - 1] = '$previous$line';
      } else {
        merged.add(line);
      }
    }

    return merged;
  }

  List<String> _cleanLines(String recognizedText) {
    final cleaned = recognizedText
        .split('\n')
        .map(_normalizeRecipeLine)
        .where((l) => !_isLikelyNoiseLine(l))
        .toList();

    return _mergeWrappedLines(cleaned);
  }

  String _extractTitle(List<String> lines) {
    return lines.firstWhere(
      _looksLikeTitleCandidate,
      orElse: () => 'Neues Rezept',
    );
  }

  String _extractIngredientsText(String recognizedText) {
    final lines = _cleanLines(recognizedText);
    final ingredients = <String>[];
    var inIngredientsSection = false;
    var inInstructionsSection = false;

    for (final line in lines) {
      if (_isIngredientHeader(line)) {
        inIngredientsSection = true;
        inInstructionsSection = false;
        continue;
      }
      if (_isInstructionsHeader(line) || _isLikelyInstructionLine(line)) {
        inInstructionsSection = true;
        if (!inIngredientsSection) {
          inIngredientsSection = false;
        }
      }
      if (inInstructionsSection) continue;
      if (_isMetaLine(line)) continue;

      if (inIngredientsSection) {
        if (line.length < 3) continue;
        ingredients.add(line);
        continue;
      }

      if (_looksLikeIngredientLine(line)) {
        ingredients.add(line);
      }
    }

    return ingredients.join('\n');
  }

  String _extractInstructionsText(String recognizedText) {
    final lines = _cleanLines(recognizedText);
    final instructions = <String>[];
    var inInstructionsSection = false;
    var inIngredientsSection = false;

    for (final line in lines) {
      if (_isIngredientHeader(line)) {
        inIngredientsSection = true;
        inInstructionsSection = false;
        continue;
      }

      if (_isInstructionsHeader(line)) {
        inInstructionsSection = true;
        inIngredientsSection = false;
        continue;
      }

      if (_isLikelyInstructionLine(line)) {
        inInstructionsSection = true;
      }

      if (inInstructionsSection) {
        instructions.add(line);
        continue;
      }

      if (!inIngredientsSection &&
          !_looksLikeIngredientLine(line) &&
          line.length > 35) {
        instructions.add(line);
      }
    }

    return instructions.join('\n');
  }

  String? _extractFirstUrl(String text) {
    final match = _urlPattern.firstMatch(text);
    return match?.group(0);
  }

  Future<void> _createDraft() async {
    final lines = _cleanLines(_recognizedText);
    final title = _extractTitle(lines);

    final ingredientsText = _extractIngredientsText(_recognizedText);
    final instructionsText = _extractInstructionsText(_recognizedText);
    final sharedText = widget.sharedText?.trim() ?? '';
    final sourceUrl = _extractFirstUrl(sharedText) ?? sharedText;

    final combinedRawText = [
      _recognizedText.trim(),
      if (sharedText.isNotEmpty) '[Geteilter Link]\n$sharedText',
    ].where((part) => part.isNotEmpty).join('\n\n');

    final saved = await context.push<bool>(
      '/new',
      extra: {
        'title': title,
        'ingredientsText': ingredientsText,
        'instructions': instructionsText,
        'imagePaths': _imagePaths,
        'fromImport': true,
        'ocrRawText': combinedRawText,
        'sourceUrl': sourceUrl,
      },
    );

    if (!mounted) return;
    context.pop(saved == true);
  }

  Future<void> _pickImagesAndImport() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();

    if (images.isEmpty) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Für die Extraktion werden Screenshots benötigt. Bitte Bilder auswählen.';
      });
      return;
    }

    if (!mounted) return;
    setState(() {
      _imagePaths = images.map((e) => e.path).toList();
      _didStartFlow = false;
      _errorMessage = null;
    });

    await _runImportFlow();
  }

  Future<void> _runImportFlow() async {
    if (_didStartFlow) return;
    if (_imagePaths.isEmpty) return;
    _didStartFlow = true;

    try {
      await _recognizeText();

      if (!mounted) return;
      await _createDraft();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Text konnte nicht erkannt werden.';
      });
    }
  }

  Future<void> _recognizeText() async {
    if (_isRecognizing) return;

    setState(() {
      _isRecognizing = true;
      _errorMessage = null;
    });

    final recognizer = TextRecognizer();
    final buffer = StringBuffer();

    try {
      for (final path in _imagePaths) {
        final inputImage = InputImage.fromFilePath(path);
        final result = await recognizer.processImage(inputImage);

        buffer.writeln(result.text);
        buffer.writeln();
      }

      if (!mounted) return;

      setState(() {
        _recognizedText = buffer.toString().trim();
      });
    } finally {
      await recognizer.close();
      if (mounted) {
        setState(() => _isRecognizing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasImages = _imagePaths.isNotEmpty;

    final statusText = _isRecognizing
        ? 'OCR läuft. Entwurf wird automatisch geöffnet...'
        : _errorMessage ??
              (hasImages
                  ? 'Bereit zur Extraktion. Du kannst bei Bedarf andere Bilder auswählen.'
                  : 'Für die Extraktion werden Screenshots benötigt.');

    final statusIcon = _isRecognizing
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          )
        : Icon(
            _errorMessage == null ? Icons.auto_awesome : Icons.error_outline,
            color: _errorMessage == null
                ? colorScheme.primary
                : colorScheme.onErrorContainer,
          );

    return Scaffold(
      appBar: AppBar(title: const Text('Rezept importieren')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primaryContainer,
                  colorScheme.tertiaryContainer.withValues(alpha: 0.72),
                ],
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                statusIcon,
                const SizedBox(width: 12),
                Expanded(child: Text(statusText)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _isRecognizing ? null : _pickImagesAndImport,
            icon: Icon(
              hasImages ? Icons.add_photo_alternate : Icons.image_search,
            ),
            label: Text(
              hasImages ? 'Andere Screenshots wählen' : 'Screenshots auswählen',
            ),
          ),
          if (hasImages) ...[
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Quellbilder',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ..._imagePaths.map(
                      (path) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(File(path), fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
