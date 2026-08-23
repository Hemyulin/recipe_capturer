import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:cookbuk/data/recipe_repository.dart';
import 'package:cookbuk/domain/recipe.dart';

class FileRecipeRepository implements RecipeRepository {
  static const _recipesFileName = 'recipes.json';
  static const _recipeImagesDirName = 'recipe_images';

  Future<Directory> _appDir() async {
    return getApplicationDocumentsDirectory();
  }

  Future<File> _recipesFile() async {
    final appDir = await _appDir();
    return File(p.join(appDir.path, _recipesFileName));
  }

  Future<Directory> _recipeImagesDir() async {
    final appDir = await _appDir();
    final dir = Directory(p.join(appDir.path, _recipeImagesDirName));

    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    return dir;
  }

  Future<List<dynamic>> _readItems() async {
    final file = await _recipesFile();
    if (!(await file.exists())) {
      return [];
    }

    final fileAsString = await file.readAsString();
    if (fileAsString.trim().isEmpty) return [];

    final decoded = jsonDecode(fileAsString);
    if (decoded is! List) return [];

    return decoded;
  }

  Future<void> _writeItems(List<dynamic> items) async {
    final file = await _recipesFile();
    await file.writeAsString(jsonEncode(items));
  }

  Future<void> _writeAll(List<Recipe> recipes) async {
    final items = recipes.map((r) => r.toJson()).toList();
    await _writeItems(items);
  }

  Future<bool> _isManagedImagePath(String path) async {
    final imagesDir = await _recipeImagesDir();
    final normalizedSource = p.normalize(path);
    final normalizedManagedDir = p.normalize(imagesDir.path);

    return normalizedSource.startsWith(normalizedManagedDir);
  }

  Future<String> _copyImageToAppStorage({
    required String sourcePath,
    required String recipeId,
    required int index,
  }) async {
    if (await _isManagedImagePath(sourcePath)) {
      return sourcePath;
    }

    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      return sourcePath;
    }

    final imagesDir = await _recipeImagesDir();
    final extension = p.extension(sourcePath).toLowerCase();
    final safeExtension = extension.isEmpty ? '.jpg' : extension;
    final fileName =
        '${recipeId}_${DateTime.now().millisecondsSinceEpoch}_$index$safeExtension';
    final targetPath = p.join(imagesDir.path, fileName);

    final copiedFile = await sourceFile.copy(targetPath);
    return copiedFile.path;
  }

  Future<List<String>> _persistImages(Recipe recipe) async {
    final result = <String>[];

    for (var i = 0; i < recipe.imagePaths.length; i++) {
      final persistedPath = await _copyImageToAppStorage(
        sourcePath: recipe.imagePaths[i],
        recipeId: recipe.id,
        index: i,
      );
      result.add(persistedPath);
    }

    return result;
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
    final persistedRecipe = recipe.copyWith(
      imagePaths: await _persistImages(recipe),
    );
    items.add(persistedRecipe.toJson());
    await _writeItems(items);
  }

  @override
  Future<void> deleteById(String id) async {
    final recipes = await getAll();
    final recipeToDelete = recipes.where((r) => r.id == id).firstOrNull;

    if (recipeToDelete != null) {
      for (final imagePath in recipeToDelete.imagePaths) {
        final file = File(imagePath);
        if (await _isManagedImagePath(imagePath) && await file.exists()) {
          try {
            await file.delete();
          } catch (_) {
            // Ignore file delete failures for now.
          }
        }
      }
    }

    final items = await _readItems();
    items.removeWhere((e) => (e as Map<String, dynamic>)['id'] == id);
    await _writeItems(items);
  }

  @override
  Future<void> update(Recipe recipe) async {
    final recipes = await getAll();
    final index = recipes.indexWhere((r) => r.id == recipe.id);
    if (index == -1) return;

    final updatedRecipe = recipe.copyWith(
      imagePaths: await _persistImages(recipe),
    );

    final updated = [...recipes];
    updated[index] = updatedRecipe;
    await _writeAll(updated);
  }
}
