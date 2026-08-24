import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

class RecipeImage extends StatefulWidget {
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
  State<RecipeImage> createState() => _RecipeImageState();
}

class _RecipeImageState extends State<RecipeImage> {
  late Future<String?> _resolvedPath;

  @override
  void initState() {
    super.initState();
    _resolvedPath = _resolvePath(widget.path);
  }

  @override
  void didUpdateWidget(covariant RecipeImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path) {
      _resolvedPath = _resolvePath(widget.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    final seed = widget.placeholderSeed ?? widget.path ?? '';
    final value = widget.path;
    if (value == null || value.isEmpty) {
      return _RecipePlaceholder(seed: seed);
    }

    if (value.startsWith('assets/')) {
      return Image.asset(
        value,
        fit: widget.fit,
        errorBuilder: (_, _, _) => _RecipePlaceholder(seed: seed),
      );
    }

    return FutureBuilder<String?>(
      future: _resolvedPath,
      builder: (context, snapshot) {
        final resolvedValue = snapshot.data;
        if (resolvedValue == null || resolvedValue.isEmpty) {
          return _RecipePlaceholder(seed: seed);
        }

        if (resolvedValue.startsWith('http://') ||
            resolvedValue.startsWith('https://')) {
          return Image.network(
            resolvedValue,
            fit: widget.fit,
            errorBuilder: (_, _, _) => _RecipePlaceholder(seed: seed),
          );
        }

        return Image.file(
          File(resolvedValue),
          fit: widget.fit,
          errorBuilder: (_, _, _) => _RecipePlaceholder(seed: seed),
        );
      },
    );
  }

  Future<String?> _resolvePath(String? value) async {
    if (value == null || value.isEmpty) return value;

    if (value.startsWith('http://') || value.startsWith('https://')) {
      return _cachedNetworkImagePath(value);
    }

    return value;
  }

  Future<String> _cachedNetworkImagePath(String url) async {
    try {
      final cacheDirectory = Directory(
        path.join((await getTemporaryDirectory()).path, 'cookbuk_image_cache'),
      );
      if (!await cacheDirectory.exists()) {
        await cacheDirectory.create(recursive: true);
      }

      final uri = Uri.parse(url);
      final extension = path.extension(uri.path).split('?').first;
      final cacheFile = File(
        path.join(cacheDirectory.path, '${_stableHash(url)}$extension'),
      );
      if (await cacheFile.exists() && await cacheFile.length() > 0) {
        return cacheFile.path;
      }

      final response = await http.get(uri).timeout(_imageCacheTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return url;
      }

      await cacheFile.writeAsBytes(response.bodyBytes, flush: true);
      return cacheFile.path;
    } catch (_) {
      return url;
    }
  }

  String _stableHash(String value) {
    var hash = 0x811c9dc5;
    for (final unit in value.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xffffffff;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static const _imageCacheTimeout = Duration(seconds: 10);
}

class _RecipePlaceholder extends StatelessWidget {
  const _RecipePlaceholder({required this.seed});

  static const _variants = [
    _PlaceholderVariant(
      icon: Icons.add_a_photo_outlined,
      background: Color(0xFFF5EFE6),
      foreground: Color(0xFF7A6854),
    ),
    _PlaceholderVariant(
      icon: Icons.photo_camera_outlined,
      background: Color(0xFFEFF3EA),
      foreground: Color(0xFF60724F),
    ),
    _PlaceholderVariant(
      icon: Icons.add_photo_alternate_outlined,
      background: Color(0xFFF4ECEC),
      foreground: Color(0xFF815E5E),
    ),
    _PlaceholderVariant(
      icon: Icons.photo_library_outlined,
      background: Color(0xFFEEF1F5),
      foreground: Color(0xFF596B80),
    ),
    _PlaceholderVariant(
      icon: Icons.camera_alt_outlined,
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
