import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:recipe_capturer/data/recipe_repository.dart';
import 'package:recipe_capturer/domain/recipe.dart';

class FileRecipeRepository implements RecipeRepository {
  Future<File> _recipesFile() async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    return File('${appDocDir.path}/recipes.json');
  }

  Future<List<dynamic>> _readItems() async {
    final file = await _recipesFile();
    if (!(await file.exists())) return [];

    final fileAsString = await file.readAsString();
    if (fileAsString.trim().isEmpty) return [];

    final decoded = jsonDecode(fileAsString);
    return decoded is List ? decoded : <dynamic>[];
  }

  Future<void> _writeItems(List<dynamic> items) async {
    final file = await _recipesFile();
    await file.writeAsString(jsonEncode(items));
  }

  Future<void> _writeAll(List<Recipe> recipes) async {
    final items = recipes.map((r) => r.toJson()).toList();
    await _writeItems(items);
  }

  @override
  Future<List<Recipe>> getAll() async {
    final items = await _readItems();
    return items
        .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> add(Recipe recipe) async {
    final items = await _readItems();
    items.add(recipe.toJson());
    await _writeItems(items);
  }

  @override
  Future<void> deleteById(String id) async {
    final items = await _readItems();
    items.removeWhere((e) => (e as Map<String, dynamic>)['id'] == id);
    await _writeItems(items);
  }

  @override
  Future<void> update(Recipe recipe) async {
    final recipes = await getAll();
    final index = recipes.indexWhere((r) => r.id == recipe.id);
    if (index == -1) return;

    final updated = [...recipes];
    updated[index] = recipe;
    await _writeAll(updated);
  }
}
