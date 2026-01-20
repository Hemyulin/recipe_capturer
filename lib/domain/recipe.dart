class Recipe {
  final String title;

  Recipe(this.title);
  factory Recipe.create(String title) {
    return Recipe(title.trim());
  }
}
