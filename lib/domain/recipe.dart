class Recipe {
  final String id;
  final String title;
  final DateTime createdAt;
  final List<String> ingredients;
  final List<String> tags;
  final bool isFavorite;

  Recipe._(
    this.id,
    this.title,
    this.createdAt,
    this.ingredients,
    this.tags,
    this.isFavorite,
  );

  factory Recipe.create(
    String title, {
    List<String>? ingredients,
    List<String>? tags,
  }) {
    final t = title.trim();
    if (t.isEmpty) {
      throw ArgumentError('Titel kann nicht leer sein!');
    }

    final cleanedIngredients = (ingredients ?? <String>[])
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final cleanedTags = (tags ?? <String>[])
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final now = DateTime.now();

    return Recipe._(
      now.microsecondsSinceEpoch.toString(),
      t,
      now,
      cleanedIngredients,
      cleanedTags,
      false, // isFavorite
    );
  }

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final id = json['id']?.toString().trim() ?? '';
    final title = json['title']?.toString().trim() ?? '';

    if (id.isEmpty) {
      throw ArgumentError('Recipe id missing');
    }
    if (title.isEmpty) {
      throw ArgumentError('Recipe title missing');
    }

    final createdAtRaw = json['createdAt'];
    final createdAt = createdAtRaw is String
        ? DateTime.tryParse(createdAtRaw) ?? DateTime.now()
        : DateTime.now();

    final ingredientsRaw = json['ingredients'];
    final ingredients = ingredientsRaw is List
        ? ingredientsRaw.map((e) => e.toString()).toList()
        : <String>[];

    final tagsRaw = json['tags'];
    final tags = tagsRaw is List
        ? tagsRaw.map((e) => e.toString()).toList()
        : <String>[];

    // Backward-compatible: older stored recipes don't have this field
    final isFavorite = (json['isFavorite'] as bool?) ?? false;

    return Recipe._(id, title, createdAt, ingredients, tags, isFavorite);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'ingredients': ingredients,
      'tags': tags,
      'isFavorite': isFavorite,
    };
  }

  Recipe withFavorite(bool value) {
    return Recipe._(id, title, createdAt, ingredients, tags, value);
  }
}
