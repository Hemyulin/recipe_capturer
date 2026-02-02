import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:recipe_capturer/data/recipe_repository.dart';
import 'package:recipe_capturer/domain/recipe.dart';

class FileRecipeRepository implements RecipeRepository {
  @override
  Future<List<Recipe>> getAll() async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();

    final file = File('${appDocDir.path}/recipes.json');
    if (!(await file.exists())) return [];

    final String fileAsString = await file.readAsString();
    if (fileAsString.trim().isEmpty) return [];

    final List<dynamic> decoded = jsonDecode(fileAsString);
    final recipes = decoded
        .map((e) => Recipe.fromJson(e as Map<String, dynamic>))
        .toList();
    return recipes;
  }

  @override
  Future<void> add(Recipe recipe) async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();

    final file = File('${appDocDir.path}/recipes.json');

    final List<dynamic> items;

    if (await file.exists()) {
      final fileAsString = await file.readAsString();
      if (fileAsString.trim().isEmpty) {
        items = [];
      } else {
        items = jsonDecode(fileAsString) as List<dynamic>;
      }
    } else {
      items = [];
    }

    items.add(recipe.toJson());

    final encoded = jsonEncode(items);
    await file.writeAsString(encoded);
  }

  @override
  Future<void> deleteById(String id) async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();

    final file = File('${appDocDir.path}/recipes.json');

    final List<dynamic> items;

    if (await file.exists()) {
      final fileAsString = await file.readAsString();
      if (fileAsString.trim().isEmpty) {
        items = [];
      } else {
        items = jsonDecode(fileAsString) as List<dynamic>;
      }
    } else {
      items = [];
    }

    items.removeWhere((e) => (e as Map<String, dynamic>)['id'] == id);

    final encoded = jsonEncode(items);
    await file.writeAsString(encoded);
  }
}
