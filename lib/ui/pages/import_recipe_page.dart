import 'dart:io';
import 'package:flutter/material.dart';
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

  void _createDraft() {
    final lines = _recognizedText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    // --- TITLE ---
    final title = lines.firstWhere(
      (l) =>
          l.length > 5 &&
          !l.toLowerCase().contains('publicaciones') &&
          !l.toLowerCase().contains('gefällt'),
      orElse: () => 'Neues Rezept',
    );

    // --- INGREDIENTS ---
    final ingredients = lines.where((l) => RegExp(r'\d').hasMatch(l)).toList();

    // Debug so you SEE what happens
    debugPrint('TITLE: $title');
    debugPrint('INGREDIENTS: $ingredients');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Titel: $title (${ingredients.length} Zutaten)')),
    );
  }

  Future<void> _recognizeText() async {
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
      recognizer.close();
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
