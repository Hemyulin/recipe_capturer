class Recipe {
  final String id;
  final String title;
  final DateTime createdAt;
  final List<String> ingredients;
  final List<String> tags;

  Recipe._(this.id, this.title, this.createdAt, this.ingredients, this.tags);

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

    return Recipe._(
      DateTime.now().microsecondsSinceEpoch.toString(),
      t,
      DateTime.now(),
      cleanedIngredients,
      cleanedTags,
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

    return Recipe._(id, title, createdAt, ingredients, tags);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'ingredients': ingredients,
      'tags': tags,
    };
  }
}
