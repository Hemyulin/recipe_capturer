import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ImportRecipePage extends StatefulWidget {
  const ImportRecipePage({super.key, required this.imagePaths});

  final List<String> imagePaths;

  @override
  State<ImportRecipePage> createState() => _ImportRecipePageState();
}

class _ImportRecipePageState extends State<ImportRecipePage> {
  String _recognizedText = '';
  bool _isRecognizing = false;

  @override
  void initState() {
    super.initState();
    _recognizeText();
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

  bool _looksLikeIngredientLine(String line) {
    final lower = line.toLowerCase().trim();

    if (lower.isEmpty) return false;
    if (_isBlockedLine(lower)) return false;

    final hasNumber = RegExp(r'\d').hasMatch(lower);
    final hasUnit = RegExp(
      r'\b(g|kg|mg|ml|l|tl|el|esslöffel|teelöffel|cup|cups)\b',
      caseSensitive: false,
    ).hasMatch(line);

    final looksTooLong = line.length > 60;

    return (hasNumber || hasUnit) && !looksTooLong;
  }

  List<String> _cleanLines(String recognizedText) {
    return recognizedText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .where((l) => !_isBlockedLine(l))
        .toList();
  }

  String _extractIngredientsText(String recognizedText) {
    final lines = _cleanLines(
      recognizedText,
    ).where(_looksLikeIngredientLine).toList();

    return lines.join('\n');
  }

  String _extractInstructionsText(String recognizedText) {
    final lines = _cleanLines(recognizedText)
        .where((line) => !_looksLikeIngredientLine(line))
        .where((line) => line.length > 20)
        .toList();

    return lines.join('\n\n');
  }

  Future<void> _createDraft() async {
    final lines = _cleanLines(_recognizedText);

    final title = lines.firstWhere(
      (l) => l.length > 5 && l.length < 50,
      orElse: () => 'Neues Rezept',
    );

    final ingredientsText = _extractIngredientsText(_recognizedText);
    final instructionsText = _extractInstructionsText(_recognizedText);

    final saved = await context.push<bool>(
      '/new',
      extra: {
        'title': title,
        'ingredientsText': ingredientsText,
        'instructions': instructionsText,
        'imagePaths': widget.imagePaths,
      },
    );

    if (!context.mounted) return;
    if (saved == true) {
      context.pop(true);
    }
  }

  Future<void> _recognizeText() async {
    if (_isRecognizing) return;

    setState(() => _isRecognizing = true);

    final recognizer = TextRecognizer();
    final buffer = StringBuffer();

    try {
      for (final path in widget.imagePaths) {
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
    return Scaffold(
      appBar: AppBar(title: const Text('Rezept importieren')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          ElevatedButton(
            onPressed: _isRecognizing ? null : _recognizeText,
            child: Text(_isRecognizing ? 'Erkenne Text...' : 'Text erkennen'),
          ),
          ElevatedButton(
            onPressed: _recognizedText.isEmpty ? null : _createDraft,
            child: const Text('Als Rezept übernehmen'),
          ),
          const SizedBox(height: 16),
          ...widget.imagePaths.map(
            (path) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(path), fit: BoxFit.cover),
              ),
            ),
          ),
          if (_recognizedText.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Erkannter Text',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SelectableText(_recognizedText),
          ],
        ],
      ),
    );
  }
}
