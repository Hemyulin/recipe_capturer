import 'package:uuid/uuid.dart';

class RecipeIngredient {
  const RecipeIngredient({
    required this.name,
    this.quantity = '',
    this.unit = '',
    this.note = '',
    this.excludeFromShopping = false,
  });

  final String name;
  final String quantity;
  final String unit;
  final String note;
  final bool excludeFromShopping;

  String get label {
    final amount = [
      quantity,
      unit,
    ].map((part) => part.trim()).where((part) => part.isNotEmpty).join(' ');
    if (amount.isEmpty) return name;
    final base = '$amount $name';
    final trimmedNote = note.trim();
    if (trimmedNote.isEmpty) return base;
    return '$base ($trimmedNote)';
  }

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return name.toLowerCase().contains(normalized) ||
        quantity.toLowerCase().contains(normalized) ||
        unit.toLowerCase().contains(normalized) ||
        note.toLowerCase().contains(normalized);
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'note': note,
      'excludeFromShopping': excludeFromShopping,
    };
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
      note: (json['note'] as String? ?? '').trim(),
      excludeFromShopping: json['excludeFromShopping'] as bool? ?? false,
    );
  }
}

class RecipeCookEvent {
  const RecipeCookEvent({required this.cookedAt, required this.mealType});

  final DateTime cookedAt;
  final String mealType;

  Map<String, dynamic> toJson() {
    return {'cookedAt': cookedAt.toIso8601String(), 'mealType': mealType};
  }

  factory RecipeCookEvent.fromJson(Map<String, dynamic> json) {
    return RecipeCookEvent(
      cookedAt: DateTime.parse(json['cookedAt'] as String),
      mealType: (json['mealType'] as String? ?? '').trim(),
    );
  }
}

class Recipe {
  final String id;
  final String title;
  final DateTime createdAt;
  final List<RecipeIngredient> ingredients;
  final List<String> instructions;
  final List<String> preparationTasks;
  final List<String> tags;
  final bool isFavorite;
  final List<String> imagePaths;
  final int? servings;
  final String season;
  final int? prepTimeMinutes;
  final int? cookTimeMinutes;
  final String notes;
  final List<RecipeCookEvent> cookEvents;

  const Recipe({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.ingredients,
    required this.instructions,
    this.preparationTasks = const [],
    required this.tags,
    required this.isFavorite,
    this.imagePaths = const [],
    this.servings,
    this.season = '',
    this.prepTimeMinutes,
    this.cookTimeMinutes,
    this.notes = '',
    this.cookEvents = const [],
  });

  String? get mainImagePath => imagePaths.isEmpty ? null : imagePaths.first;

  int get cookCount => cookEvents.length;

  DateTime? get lastCookedAt {
    if (cookEvents.isEmpty) return null;
    return cookEvents
        .map((event) => event.cookedAt)
        .reduce((a, b) => a.isAfter(b) ? a : b);
  }

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
    List<String> preparationTasks = const [],
    List<String> tags = const [],
    bool isFavorite = false,
    List<String> imagePaths = const [],
    int? servings,
    String season = '',
    int? prepTimeMinutes,
    int? cookTimeMinutes,
    String notes = '',
    List<RecipeCookEvent> cookEvents = const [],
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
      preparationTasks: preparationTasks
          .map((task) => task.trim())
          .where((task) => task.isNotEmpty)
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
      cookEvents: cookEvents,
    );
  }

  Recipe copyWith({
    String? id,
    String? title,
    DateTime? createdAt,
    List<RecipeIngredient>? ingredients,
    List<String>? instructions,
    List<String>? preparationTasks,
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
    List<RecipeCookEvent>? cookEvents,
  }) {
    return Recipe(
      id: id ?? this.id,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      ingredients: ingredients ?? this.ingredients,
      instructions: instructions ?? this.instructions,
      preparationTasks: preparationTasks ?? this.preparationTasks,
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
      cookEvents: cookEvents ?? this.cookEvents,
    );
  }

  Recipe withFavorite(bool value) {
    return copyWith(isFavorite: value);
  }

  Recipe withCookEvent({required String mealType, DateTime? at}) {
    return copyWith(
      cookEvents: [
        ...cookEvents,
        RecipeCookEvent(cookedAt: at ?? DateTime.now(), mealType: mealType),
      ],
    );
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
      'preparationTasks': preparationTasks,
      'tags': tags,
      'isFavorite': isFavorite,
      'imagePaths': imagePaths,
      'servings': servings,
      'season': season,
      'prepTimeMinutes': prepTimeMinutes,
      'cookTimeMinutes': cookTimeMinutes,
      'notes': notes,
      'cookCount': cookCount,
      'lastCookedAt': lastCookedAt?.toIso8601String(),
      'cookEvents': cookEvents.map((event) => event.toJson()).toList(),
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

    final rawCookEvents = json['cookEvents'];
    final cookEvents = rawCookEvents is List
        ? rawCookEvents
              .whereType<Map<String, dynamic>>()
              .map(RecipeCookEvent.fromJson)
              .toList()
        : _legacyCookEvents(json);

    return Recipe(
      id: json['id'] as String,
      title: json['title'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      ingredients: (json['ingredients'] as List<dynamic>? ?? [])
          .map(RecipeIngredient.fromJson)
          .where((ingredient) => ingredient.name.isNotEmpty)
          .toList(),
      instructions: instructions,
      preparationTasks: (json['preparationTasks'] as List<dynamic>? ?? [])
          .map((task) => task.toString().trim())
          .where((task) => task.isNotEmpty)
          .toList(),
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
      cookEvents: cookEvents,
    );
  }

  static List<RecipeCookEvent> _legacyCookEvents(Map<String, dynamic> json) {
    final count = json['cookCount'] as int? ?? 0;
    final lastCookedAt = json['lastCookedAt'] == null
        ? null
        : DateTime.parse(json['lastCookedAt'] as String);

    if (count <= 0 || lastCookedAt == null) return const [];

    return List.generate(
      count,
      (_) => RecipeCookEvent(cookedAt: lastCookedAt, mealType: ''),
    );
  }
}
