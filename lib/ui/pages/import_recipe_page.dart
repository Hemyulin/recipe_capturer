import 'package:flutter/material.dart';

class ImportRecipePage extends StatelessWidget {
  const ImportRecipePage({super.key, required this.imagePaths});

  final List<String> imagePaths;

  @override
  Widget build(BuildContext context) {
    final count = imagePaths.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Rezept importieren')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Text('$count Screenshots ausgewählt'),
      ),
    );
  }
}
