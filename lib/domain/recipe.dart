class Recipe {
  final String id;
  final String title;

  Recipe._(this.id, this.title);

  factory Recipe.create(String title) {
    final t = title.trim();
    if (t.isEmpty) {
      throw ArgumentError('Titel kann nicht leer sein!');
    }

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    return Recipe._(id, t);
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'title': title};
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

    return Recipe._(id, title);
  }
}
