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
}
