import 'dart:io';

import 'package:flutter/material.dart';

class ImportRecipePage extends StatelessWidget {
  const ImportRecipePage({super.key, required this.imagePaths});

  final List<String> imagePaths;

  @override
  Widget build(BuildContext context) {
    final count = imagePaths.length;

    return Scaffold(
      appBar: AppBar(title: const Text('Rezept importieren')),
      body: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: imagePaths.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final path = imagePaths[index];

          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(File(path), fit: BoxFit.cover),
          );
        },
      ),
    );
  }
}
