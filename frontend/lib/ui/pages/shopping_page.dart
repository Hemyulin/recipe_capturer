import 'package:flutter/material.dart';
import 'package:cookbuk/data/meal_plan_repository.dart';
import 'package:cookbuk/data/recipe_repository.dart';
import 'package:cookbuk/domain/recipe.dart';
import 'package:cookbuk/ui/widgets/load_state_view.dart';

class ShoppingPage extends StatefulWidget {
  const ShoppingPage({
    super.key,
    required this.repo,
    required this.mealPlanRepo,
  });

  final RecipeRepository repo;
  final MealPlanRepository mealPlanRepo;

  @override
  State<ShoppingPage> createState() => _ShoppingPageState();
}

class _ShoppingPageState extends State<ShoppingPage> {
  late DateTime _weekStart = _startOfWeek(DateTime.now());
  bool _isLoading = true;
  String? _loadError;
  List<_ShoppingItem> _items = [];
  Set<String> _checkedItemKeys = {};
  int _plannedRecipeCount = 0;

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 6));

  @override
  void initState() {
    super.initState();
    _loadList();
  }

  Future<void> _loadList() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final recipes = await widget.repo.getAll();
      final recipeById = {for (final recipe in recipes) recipe.id: recipe};
      final slots = await widget.mealPlanRepo.getRange(
        from: _weekStart,
        to: _weekEnd,
      );
      final plannedRecipes = [
        for (final slot in slots)
          if (slot.isRecipe && slot.recipeId != null) recipeById[slot.recipeId],
      ].whereType<Recipe>().toList();

      if (!mounted) return;
      setState(() {
        _plannedRecipeCount = plannedRecipes.length;
        _items = _ShoppingItem.fromRecipes(plannedRecipes);
        _checkedItemKeys = _checkedItemKeys.intersection(
          _items.map((item) => item.key).toSet(),
        );
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Backend nicht erreichbar.';
      });
    }
  }

  Future<void> _moveWeek(int delta) async {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * delta));
      _checkedItemKeys = {};
    });
    await _loadList();
  }

  Future<void> _showCurrentWeek() async {
    setState(() {
      _weekStart = _startOfWeek(DateTime.now());
      _checkedItemKeys = {};
    });
    await _loadList();
  }

  void _toggleItem(String key, bool? value) {
    setState(() {
      if (value ?? false) {
        _checkedItemKeys.add(key);
      } else {
        _checkedItemKeys.remove(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final checkedCount = _checkedItemKeys.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einkauf'),
        actions: [
          IconButton(
            onPressed: _showCurrentWeek,
            icon: const Icon(Icons.today_outlined),
            tooltip: 'Diese Woche',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadList,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            _ShoppingWeekHeader(
              label: _weekLabel(_weekStart, _weekEnd),
              onPrevious: () => _moveWeek(-1),
              onNext: () => _moveWeek(1),
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: LoadStateView.loading(),
              )
            else if (_loadError != null)
              SizedBox(
                height: 360,
                child: LoadStateView.error(
                  title: 'Einkaufsliste konnte nicht geladen werden',
                  message:
                      'Prüfe, ob der CookBuk-Backendserver läuft und dein Gerät im Tailscale ist.',
                  onRetry: _loadList,
                ),
              )
            else if (_items.isEmpty)
              SizedBox(
                height: 360,
                child: _EmptyShoppingList(onRefresh: _loadList),
              )
            else ...[
              _ShoppingSummary(
                plannedRecipeCount: _plannedRecipeCount,
                checkedCount: checkedCount,
                totalCount: _items.length,
              ),
              const SizedBox(height: 12),
              for (final item in _items)
                _ShoppingItemTile(
                  item: item,
                  isChecked: _checkedItemKeys.contains(item.key),
                  onChanged: (value) => _toggleItem(item.key, value),
                ),
            ],
          ],
        ),
      ),
    );
  }

  static DateTime _startOfWeek(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    return dateOnly.subtract(Duration(days: dateOnly.weekday - 1));
  }

  static String _weekLabel(DateTime start, DateTime end) {
    return '${_shortDate(start)} - ${_shortDate(end)}';
  }

  static String _shortDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.';
  }
}

class _EmptyShoppingList extends StatelessWidget {
  const _EmptyShoppingList({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.shopping_basket_outlined,
              size: 38,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Noch keine Einkaufsliste',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Plane ein paar Rezepte in der Woche, dann sammeln wir hier die Zutaten.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Aktualisieren'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShoppingWeekHeader extends StatelessWidget {
  const _ShoppingWeekHeader({
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  final String label;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
          tooltip: 'Vorige Woche',
        ),
        Expanded(
          child: Center(
            child: Text(label, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
          tooltip: 'Nächste Woche',
        ),
      ],
    );
  }
}

class _ShoppingSummary extends StatelessWidget {
  const _ShoppingSummary({
    required this.plannedRecipeCount,
    required this.checkedCount,
    required this.totalCount,
  });

  final int plannedRecipeCount;
  final int checkedCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(Icons.shopping_basket_outlined, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$plannedRecipeCount Rezepte, $totalCount Zutaten',
                style: textTheme.titleSmall,
              ),
            ),
            Text(
              '$checkedCount/$totalCount',
              style: textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShoppingItemTile extends StatelessWidget {
  const _ShoppingItemTile({
    required this.item,
    required this.isChecked,
    required this.onChanged,
  });

  final _ShoppingItem item;
  final bool isChecked;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return CheckboxListTile(
      value: isChecked,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(
        item.title,
        style: textTheme.bodyLarge?.copyWith(
          decoration: isChecked ? TextDecoration.lineThrough : null,
          color: isChecked ? colorScheme.onSurfaceVariant : null,
        ),
      ),
      subtitle: item.sources.isEmpty
          ? null
          : Text(
              item.sources.join(', '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
    );
  }
}

class _ShoppingItem {
  const _ShoppingItem({
    required this.key,
    required this.name,
    required this.quantityLabel,
    required this.sources,
  });

  final String key;
  final String name;
  final String quantityLabel;
  final List<String> sources;

  String get title {
    if (quantityLabel.isEmpty) return name;
    return '$quantityLabel $name';
  }

  static List<_ShoppingItem> fromRecipes(List<Recipe> recipes) {
    final builders = <String, _ShoppingItemBuilder>{};

    for (final recipe in recipes) {
      for (final ingredient in recipe.ingredients) {
        final name = ingredient.name.trim();
        if (name.isEmpty) continue;
        final unit = ingredient.unit.trim();
        final key = '${name.toLowerCase()}|${unit.toLowerCase()}';
        final builder = builders.putIfAbsent(
          key,
          () => _ShoppingItemBuilder(name: name, unit: unit),
        );
        builder.add(ingredient.quantity.trim(), recipe.title);
      }
    }

    final items = builders.entries
        .map((entry) => entry.value.build(entry.key))
        .toList();
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }
}

class _ShoppingItemBuilder {
  _ShoppingItemBuilder({required this.name, required this.unit});

  final String name;
  final String unit;
  final Set<String> sources = {};
  final List<String> rawQuantities = [];
  double total = 0;
  bool onlyNumericQuantities = true;

  void add(String quantity, String source) {
    sources.add(source);
    if (quantity.isEmpty) return;

    rawQuantities.add(quantity);
    final parsed = double.tryParse(quantity.replaceAll(',', '.'));
    if (parsed == null) {
      onlyNumericQuantities = false;
      return;
    }
    total += parsed;
  }

  _ShoppingItem build(String key) {
    return _ShoppingItem(
      key: key,
      name: name,
      quantityLabel: _quantityLabel(),
      sources: sources.toList()..sort(),
    );
  }

  String _quantityLabel() {
    if (rawQuantities.isEmpty) return '';
    if (onlyNumericQuantities) {
      final amount = total % 1 == 0
          ? total.toInt().toString()
          : total.toStringAsFixed(1).replaceAll('.', ',');
      return [amount, unit].where((part) => part.isNotEmpty).join(' ');
    }

    final quantities = rawQuantities.toSet().join(' + ');
    return [quantities, unit].where((part) => part.isNotEmpty).join(' ');
  }
}
