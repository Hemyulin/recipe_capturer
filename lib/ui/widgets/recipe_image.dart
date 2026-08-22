import 'dart:io';

import 'package:flutter/material.dart';

class RecipeImage extends StatelessWidget {
  const RecipeImage({super.key, required this.path, this.fit = BoxFit.cover});

  final String? path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final value = path;
    if (value == null || value.isEmpty) {
      return Image.asset('assets/recipe_placeholder.jpg', fit: fit);
    }

    if (value.startsWith('assets/')) {
      return Image.asset(
        value,
        fit: fit,
        errorBuilder: (_, _, _) =>
            Image.asset('assets/recipe_placeholder.jpg', fit: fit),
      );
    }

    return Image.file(
      File(value),
      fit: fit,
      errorBuilder: (_, _, _) =>
          Image.asset('assets/recipe_placeholder.jpg', fit: fit),
    );
  }
}
