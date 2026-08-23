import 'dart:io';

import 'package:flutter/material.dart';

class RecipeImage extends StatelessWidget {
  const RecipeImage({
    super.key,
    required this.path,
    this.fit = BoxFit.cover,
    this.placeholderSeed,
  });

  final String? path;
  final BoxFit fit;
  final String? placeholderSeed;

  @override
  Widget build(BuildContext context) {
    final value = path;
    final seed = placeholderSeed ?? value ?? '';
    if (value == null || value.isEmpty) {
      return _RecipePlaceholder(seed: seed);
    }

    if (value.startsWith('assets/')) {
      return Image.asset(
        value,
        fit: fit,
        errorBuilder: (_, _, _) => _RecipePlaceholder(seed: seed),
      );
    }

    return Image.file(
      File(value),
      fit: fit,
      errorBuilder: (_, _, _) => _RecipePlaceholder(seed: seed),
    );
  }
}

class _RecipePlaceholder extends StatelessWidget {
  const _RecipePlaceholder({required this.seed});

  static const _variants = [
    _PlaceholderVariant(
      icon: Icons.flatware_rounded,
      background: Color(0xFFF5EFE6),
      foreground: Color(0xFF7A6854),
    ),
    _PlaceholderVariant(
      icon: Icons.restaurant_menu_rounded,
      background: Color(0xFFEFF3EA),
      foreground: Color(0xFF60724F),
    ),
    _PlaceholderVariant(
      icon: Icons.ramen_dining_rounded,
      background: Color(0xFFF4ECEC),
      foreground: Color(0xFF815E5E),
    ),
    _PlaceholderVariant(
      icon: Icons.bakery_dining_rounded,
      background: Color(0xFFEEF1F5),
      foreground: Color(0xFF596B80),
    ),
    _PlaceholderVariant(
      icon: Icons.local_dining_rounded,
      background: Color(0xFFF3F0D9),
      foreground: Color(0xFF756F3F),
    ),
  ];

  final String seed;

  @override
  Widget build(BuildContext context) {
    final variant = _variants[_hash(seed) % _variants.length];

    return ColoredBox(
      color: variant.background,
      child: Center(
        child: Icon(
          variant.icon,
          color: variant.foreground,
          size: 38,
          semanticLabel: 'Rezeptbild Platzhalter',
        ),
      ),
    );
  }

  int _hash(String value) {
    if (value.isEmpty) return 0;
    return value.codeUnits.fold(0, (hash, unit) => hash + unit);
  }
}

class _PlaceholderVariant {
  const _PlaceholderVariant({
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
}
