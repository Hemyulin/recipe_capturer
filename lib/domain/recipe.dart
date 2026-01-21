class Recipe {
  final String title;

  Recipe._(this.title);

  factory Recipe.create(String title) {
    final t = title.trim();
    if (t.isEmpty) {
      throw ArgumentError('Titel kann nicht leer sein!');
    }
    return Recipe._(t);
  }
}
