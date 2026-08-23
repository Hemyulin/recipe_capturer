import 'package:flutter/material.dart';
import 'package:cookbuk/domain/recipe.dart';
import 'package:cookbuk/ui/widgets/meal_choice_sheet.dart';

class MealExtrasSheet extends StatefulWidget {
  const MealExtrasSheet({
    super.key,
    required this.initialExtras,
    this.initialRecipeExtraIds = const [],
    this.recipes = const [],
  });

  final List<String> initialExtras;
  final List<String> initialRecipeExtraIds;
  final List<Recipe> recipes;

  @override
  State<MealExtrasSheet> createState() => _MealExtrasSheetState();
}

class MealExtrasResult {
  const MealExtrasResult({required this.extras, required this.recipeExtraIds});

  final List<String> extras;
  final List<String> recipeExtraIds;
}

class _MealExtrasSheetState extends State<MealExtrasSheet> {
  static const _quickExtras = [
    'Brot',
    'Salat',
    'Quark',
    'Butter',
    'Hummus',
    'Reis',
  ];

  late final TextEditingController _controller = TextEditingController(
    text: widget.initialExtras.join(', '),
  );
  late final List<String> _recipeExtraIds = [...widget.initialRecipeExtraIds];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<String> _extras() {
    return _controller.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .take(8)
        .toList();
  }

  void _toggleQuickExtra(String value) {
    final extras = _extras();
    setState(() {
      if (extras.contains(value)) {
        extras.remove(value);
      } else {
        extras.add(value);
      }
      _controller.text = extras.join(', ');
    });
  }

  Recipe? _recipeById(String id) {
    for (final recipe in widget.recipes) {
      if (recipe.id == id) return recipe;
    }
    return null;
  }

  Future<void> _addRecipeExtra() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => MealChoiceSheet(recipes: widget.recipes),
    );
    if (selected == null ||
        selected == MealChoiceSheet.leftoversValue ||
        _recipeExtraIds.contains(selected)) {
      return;
    }
    setState(() => _recipeExtraIds.add(selected));
  }

  MealExtrasResult _result() {
    return MealExtrasResult(extras: _extras(), recipeExtraIds: _recipeExtraIds);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _extras();
    final selectedRecipes = _recipeExtraIds
        .map(_recipeById)
        .whereType<Recipe>()
        .toList();
    final maxHeight = MediaQuery.sizeOf(context).height * 0.82;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          4,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Extras', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    labelText: 'Beilagen und Extras',
                    hintText: 'Brot, Hummus, Salat',
                  ),
                  autofocus: true,
                  onChanged: (_) => setState(() {}),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => Navigator.of(context).pop(_result()),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final extra in _quickExtras)
                      FilterChip(
                        label: Text(extra),
                        selected: selected.contains(extra),
                        onSelected: (_) => _toggleQuickExtra(extra),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final recipe in selectedRecipes)
                      InputChip(
                        label: Text(recipe.title),
                        selected: true,
                        onDeleted: () =>
                            setState(() => _recipeExtraIds.remove(recipe.id)),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.menu_book_outlined, size: 18),
                      label: const Text('Rezept'),
                      onPressed: _addRecipeExtra,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(
                        const MealExtrasResult(extras: [], recipeExtraIds: []),
                      ),
                      child: const Text('Leeren'),
                    ),
                    const Spacer(),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(_result()),
                      child: const Text('Fertig'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
