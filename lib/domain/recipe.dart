import 'package:uuid/uuid.dart';

class Recipe {
  final String id;
  final String title;
  final DateTime createdAt;
  final List<String> ingredients;
  final List<String> tags;
  final bool isFavorite;
  final String instructions;
  final List<String> imagePaths;

  const Recipe({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.ingredients,
    required this.tags,
    required this.isFavorite,
    required this.instructions,
    this.imagePaths = const [],
  });

  factory Recipe.create(
    String title, {
    List<String> ingredients = const [],
    List<String> tags = const [],
    bool isFavorite = false,
    String instructions = '',
    List<String> imagePaths = const [],
  }) {
    final trimmedTitle = title.trim();

    if (trimmedTitle.isEmpty) {
      throw ArgumentError('Recipe title cannot be empty');
    }

    return Recipe(
      id: const Uuid().v4(),
      title: trimmedTitle,
      createdAt: DateTime.now(),
      ingredients: ingredients
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(),
      tags: tags,
      isFavorite: isFavorite,
      instructions: instructions.trim(),
      imagePaths: imagePaths,
    );
  }

  Recipe copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    List<String>? ingredients,
    List<String>? tags,
    bool? isFavorite,
    String? instructions,
    List<String>? imagePaths,
  }) {
    return Recipe(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      ingredients: ingredients ?? this.ingredients,
      tags: tags ?? this.tags,
      isFavorite: isFavorite ?? this.isFavorite,
      instructions: instructions ?? this.instructions,
      imagePaths: imagePaths ?? this.imagePaths,
    );
  }

  Recipe withFavorite(bool value) {
    return copyWith(isFavorite: value);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'ingredients': ingredients,
      'tags': tags,
      'isFavorite': isFavorite,
      'instructions': instructions,
      'imagePaths': imagePaths,
    };
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      ingredients: (json['ingredients'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      tags: (json['tags'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      isFavorite: json['isFavorite'] as bool? ?? false,
      instructions: json['instructions'] as String? ?? '',
      imagePaths: (json['imagePaths'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}
