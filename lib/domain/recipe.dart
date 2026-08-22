import 'package:uuid/uuid.dart';

class RecipeIngredient {
  const RecipeIngredient({
    required this.name,
    this.quantity = '',
    this.unit = '',
  });

  final String name;
  final String quantity;
  final String unit;

  String get label {
    final amount = [
      quantity,
      unit,
    ].map((part) => part.trim()).where((part) => part.isNotEmpty).join(' ');
    if (amount.isEmpty) return name;
    return '$amount $name';
  }

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return name.toLowerCase().contains(normalized) ||
        quantity.toLowerCase().contains(normalized) ||
        unit.toLowerCase().contains(normalized);
  }

  Map<String, dynamic> toJson() {
    return {'name': name, 'quantity': quantity, 'unit': unit};
  }

  factory RecipeIngredient.fromJson(dynamic value) {
    if (value is String) {
      return RecipeIngredient(name: value.trim());
    }

    final json = value as Map<String, dynamic>? ?? const {};
    return RecipeIngredient(
      name: (json['name'] as String? ?? '').trim(),
      quantity: (json['quantity'] as String? ?? '').trim(),
      unit: (json['unit'] as String? ?? '').trim(),
    );
  }
}

class Recipe {
  final String id;
  final String title;
  final DateTime createdAt;
  final List<RecipeIngredient> ingredients;
  final List<String> instructions;
  final List<String> tags;
  final bool isFavorite;
  final List<String> imagePaths;
  final int? servings;
  final String season;
  final int? prepTimeMinutes;
  final int? cookTimeMinutes;
  final String notes;

  const Recipe({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.ingredients,
    required this.instructions,
    required this.tags,
    required this.isFavorite,
    this.imagePaths = const [],
    this.servings,
    this.season = '',
    this.prepTimeMinutes,
    this.cookTimeMinutes,
    this.notes = '',
  });

  String? get mainImagePath => imagePaths.isEmpty ? null : imagePaths.first;

  int? get totalTimeMinutes {
    final prep = prepTimeMinutes ?? 0;
    final cook = cookTimeMinutes ?? 0;
    final total = prep + cook;
    return total == 0 ? null : total;
  }

  factory Recipe.create(
    String title, {
    List<RecipeIngredient> ingredients = const [],
    List<String> instructions = const [],
    List<String> tags = const [],
    bool isFavorite = false,
    List<String> imagePaths = const [],
    int? servings,
    String season = '',
    int? prepTimeMinutes,
    int? cookTimeMinutes,
    String notes = '',
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
          .where((ingredient) => ingredient.name.trim().isNotEmpty)
          .toList(),
      instructions: instructions
          .map((step) => step.trim())
          .where((step) => step.isNotEmpty)
          .toList(),
      tags: tags
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toSet()
          .toList(),
      isFavorite: isFavorite,
      imagePaths: imagePaths,
      servings: servings,
      season: season.trim(),
      prepTimeMinutes: prepTimeMinutes,
      cookTimeMinutes: cookTimeMinutes,
      notes: notes.trim(),
    );
  }

  Recipe copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    List<RecipeIngredient>? ingredients,
    List<String>? instructions,
    List<String>? tags,
    bool? isFavorite,
    List<String>? imagePaths,
    int? servings,
    bool clearServings = false,
    String? season,
    int? prepTimeMinutes,
    bool clearPrepTime = false,
    int? cookTimeMinutes,
    bool clearCookTime = false,
    String? notes,
  }) {
    return Recipe(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      tags: tags ?? this.tags,
      isFavorite: isFavorite ?? this.isFavorite,
      imagePaths: imagePaths ?? this.imagePaths,
      servings: clearServings ? null : servings ?? this.servings,
      season: season ?? this.season,
      prepTimeMinutes: clearPrepTime
          ? null
          : prepTimeMinutes ?? this.prepTimeMinutes,
      cookTimeMinutes: clearCookTime
          ? null
          : cookTimeMinutes ?? this.cookTimeMinutes,
      notes: notes ?? this.notes,
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
      'ingredients': ingredients
          .map((ingredient) => ingredient.toJson())
          .toList(),
      'instructions': instructions,
      'tags': tags,
      'isFavorite': isFavorite,
      'imagePaths': imagePaths,
      'servings': servings,
      'season': season,
      'prepTimeMinutes': prepTimeMinutes,
      'cookTimeMinutes': cookTimeMinutes,
      'notes': notes,
    };
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final rawInstructions = json['instructions'];
    final instructions = rawInstructions is List
        ? rawInstructions.map((step) => step.toString()).toList()
        : (rawInstructions as String? ?? '')
              .split(RegExp(r'\n{2,}|\n'))
              .map((step) => step.trim())
              .where((step) => step.isNotEmpty)
              .toList();

    return Recipe(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      ingredients: (json['ingredients'] as List<dynamic>? ?? [])
          .map(RecipeIngredient.fromJson)
          .where((ingredient) => ingredient.name.isNotEmpty)
          .toList(),
      instructions: instructions,
      tags: (json['tags'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      isFavorite: json['isFavorite'] as bool? ?? false,
      imagePaths: (json['imagePaths'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      servings: json['servings'] as int?,
      season: json['season'] as String? ?? '',
      prepTimeMinutes: json['prepTimeMinutes'] as int?,
      cookTimeMinutes: json['cookTimeMinutes'] as int?,
      notes: json['notes'] as String? ?? '',
    );
  }
}
