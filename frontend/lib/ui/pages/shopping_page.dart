import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cookbuk/data/meal_plan_repository.dart';
import 'package:cookbuk/domain/meal_plan_slot.dart';
import 'package:cookbuk/data/recipe_repository.dart';
import 'package:cookbuk/domain/recipe.dart';
import 'package:cookbuk/ui/widgets/backend_connection_icon.dart';
import 'package:cookbuk/ui/widgets/load_state_view.dart';

enum _ShoppingViewMode { combined, byRecipe, byDay }

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
  List<_ShoppingGroup> _recipeGroups = [];
  List<_ShoppingGroup> _dayGroups = [];
  Set<String> _checkedItemKeys = {};
  int _plannedRecipeCount = 0;
  _ShoppingViewMode _viewMode = _ShoppingViewMode.combined;

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 6));
  List<_ShoppingItem> get _visibleItems => switch (_viewMode) {
    _ShoppingViewMode.combined => _items,
    _ShoppingViewMode.byRecipe => [
      for (final group in _recipeGroups) ...group.items,
    ],
    _ShoppingViewMode.byDay => [for (final group in _dayGroups) ...group.items],
  };

  List<_ShoppingGroup> get _visibleGroups => switch (_viewMode) {
    _ShoppingViewMode.combined => const [],
    _ShoppingViewMode.byRecipe => _recipeGroups,
    _ShoppingViewMode.byDay => _dayGroups,
  };

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
      final sortedSlots = [...slots]..sort(_compareSlots);
      final plannedRecipes = [
        for (final slot in sortedSlots)
          if (slot.isRecipe && slot.recipeId != null) recipeById[slot.recipeId],
      ].whereType<Recipe>().toList();
      final sideRecipes = [
        for (final slot in sortedSlots)
          for (final recipeId in slot.recipeExtraIds) recipeById[recipeId],
      ].whereType<Recipe>().toList();
      final extras = [
        for (final slot in sortedSlots)
          for (final extra in slot.extras) extra,
      ];
      final items = _ShoppingItem.fromRecipesAndExtras([
        ...plannedRecipes,
        ...sideRecipes,
      ], extras);
      final recipeGroups = _recipeGroupsFromSlots(sortedSlots, recipeById);
      final dayGroups = _dayGroupsFromSlots(
        _weekStart,
        sortedSlots,
        recipeById,
      );
      final visibleKeys = {
        for (final item in items) item.key,
        for (final group in recipeGroups)
          for (final item in group.items) item.key,
        for (final group in dayGroups)
          for (final item in group.items) item.key,
      };

      if (!mounted) return;
      setState(() {
        _plannedRecipeCount = plannedRecipes.length;
        _items = items;
        _recipeGroups = recipeGroups;
        _dayGroups = dayGroups;
        _checkedItemKeys = _checkedItemKeys.intersection(visibleKeys);
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

  Future<void> _copyShoppingList() async {
    if (_visibleItems.isEmpty) return;

    final text = _viewMode == _ShoppingViewMode.combined
        ? _items.map((item) => item.title).join('\n')
        : _visibleGroups
              .map(
                (group) => [
                  group.title,
                  for (final item in group.items) '- ${item.title}',
                ].join('\n'),
              )
              .join('\n\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Einkaufsliste kopiert.')));
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _visibleItems;
    final hasShoppingItems =
        !_isLoading && _loadError == null && _items.isNotEmpty;
    final checkedVisibleCount = visibleItems
        .where((item) => _checkedItemKeys.contains(item.key))
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einkauf'),
        actions: [
          BackendConnectionIcon(mealPlanRepo: widget.mealPlanRepo),
          IconButton(
            onPressed: _items.isEmpty ? null : _copyShoppingList,
            icon: const Icon(Icons.content_copy_rounded),
            tooltip: 'Einkaufsliste kopieren',
          ),
          IconButton(
            onPressed: _showCurrentWeek,
            icon: const Icon(Icons.today_outlined),
            tooltip: 'Diese Woche',
          ),
        ],
      ),
      body: Column(
        children: [
          _ShoppingStickyHeader(
            weekLabel: _weekLabel(_weekStart, _weekEnd),
            onPrevious: () => _moveWeek(-1),
            onNext: () => _moveWeek(1),
            showListControls: hasShoppingItems,
            plannedRecipeCount: _plannedRecipeCount,
            checkedCount: checkedVisibleCount,
            totalCount: visibleItems.length,
            viewMode: _viewMode,
            onViewModeChanged: (value) => setState(() => _viewMode = value),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadList,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [
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
                  else if (_viewMode == _ShoppingViewMode.combined)
                    for (final item in _items)
                      _ShoppingItemTile(
                        item: item,
                        isChecked: _checkedItemKeys.contains(item.key),
                        onChanged: (value) => _toggleItem(item.key, value),
                      )
                  else
                    for (final group in _visibleGroups)
                      _ShoppingGroupSection(
                        group: group,
                        checkedItemKeys: _checkedItemKeys,
                        onChanged: _toggleItem,
                      ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static DateTime _startOfWeek(DateTime date) {
    final dateOnly = DateTime(date.year, date.month, date.day);
    return dateOnly.subtract(Duration(days: dateOnly.weekday - 1));
  }

  static String _weekLabel(DateTime start, DateTime end) {
    return '${_fullDate(start)} - ${_fullDate(end)}';
  }

  static String _shortDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.';
  }

  static String _fullDate(DateTime date) {
    return '${_shortDate(date)}${date.year}';
  }

  static int _compareSlots(MealPlanSlot a, MealPlanSlot b) {
    final dateCompare = a.plannedFor.compareTo(b.plannedFor);
    if (dateCompare != 0) return dateCompare;
    return _mealOrder(a.meal).compareTo(_mealOrder(b.meal));
  }

  static int _mealOrder(String meal) {
    return switch (meal) {
      'breakfast' => 0,
      'lunch' => 1,
      'dinner' => 2,
      _ => 3,
    };
  }

  static String _mealLabel(String meal) {
    return switch (meal) {
      'breakfast' => 'Frühstück',
      'lunch' => 'Mittagessen',
      'dinner' => 'Abendessen',
      _ => meal,
    };
  }

  static String _dayLabel(DateTime date) {
    final weekday = switch (date.weekday) {
      DateTime.monday => 'Montag',
      DateTime.tuesday => 'Dienstag',
      DateTime.wednesday => 'Mittwoch',
      DateTime.thursday => 'Donnerstag',
      DateTime.friday => 'Freitag',
      DateTime.saturday => 'Samstag',
      DateTime.sunday => 'Sonntag',
      _ => '',
    };
    return '$weekday, ${_shortDate(date)}';
  }

  static List<_ShoppingGroup> _recipeGroupsFromSlots(
    List<MealPlanSlot> slots,
    Map<String, Recipe> recipeById,
  ) {
    final groups = <_ShoppingGroup>[];

    for (final slot in slots) {
      final subtitle =
          '${_dayLabel(slot.plannedFor)} · ${_mealLabel(slot.meal)}';
      if (slot.isRecipe && slot.recipeId != null) {
        final recipe = recipeById[slot.recipeId];
        if (recipe != null) {
          final items = _ShoppingItem.fromRecipesAndExtras(
            [recipe],
            const [],
          ).scoped('recipe:${slot.plannedFor}:${slot.meal}:${recipe.id}');
          if (items.isNotEmpty) {
            groups.add(
              _ShoppingGroup(
                title: recipe.title,
                subtitle: subtitle,
                items: items,
              ),
            );
          }
        }
      }

      for (final recipeId in slot.recipeExtraIds) {
        final recipe = recipeById[recipeId];
        if (recipe == null) continue;
        final items = _ShoppingItem.fromRecipesAndExtras(
          [recipe],
          const [],
        ).scoped('side:${slot.plannedFor}:${slot.meal}:${recipe.id}');
        if (items.isEmpty) continue;
        groups.add(
          _ShoppingGroup(
            title: recipe.title,
            subtitle: '$subtitle · Beilage',
            items: items,
          ),
        );
      }

      final extraItems = _ShoppingItem.fromRecipesAndExtras(
        const [],
        slot.extras,
      ).scoped('extras:${slot.plannedFor}:${slot.meal}');
      if (extraItems.isNotEmpty) {
        groups.add(
          _ShoppingGroup(
            title: 'Extras',
            subtitle: subtitle,
            items: extraItems,
          ),
        );
      }
    }

    return groups;
  }

  static List<_ShoppingGroup> _dayGroupsFromSlots(
    DateTime weekStart,
    List<MealPlanSlot> slots,
    Map<String, Recipe> recipeById,
  ) {
    final groups = <_ShoppingGroup>[];

    for (var offset = 0; offset < 7; offset++) {
      final date = weekStart.add(Duration(days: offset));
      final daySlots = slots.where((slot) => _isSameDay(slot.plannedFor, date));
      final recipes = [
        for (final slot in daySlots)
          if (slot.isRecipe && slot.recipeId != null) recipeById[slot.recipeId],
        for (final slot in daySlots)
          for (final recipeId in slot.recipeExtraIds) recipeById[recipeId],
      ].whereType<Recipe>().toList();
      final extras = [
        for (final slot in daySlots)
          for (final extra in slot.extras) extra,
      ];
      final items = _ShoppingItem.fromRecipesAndExtras(
        recipes,
        extras,
      ).scoped('day:$date');
      if (items.isEmpty) continue;
      groups.add(
        _ShoppingGroup(
          title: _dayLabel(date),
          subtitle: _recipeCountLabel(recipes.length),
          items: items,
        ),
      );
    }

    return groups;
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _recipeCountLabel(int count) {
    if (count == 1) return '1 Rezept';
    return '$count Rezepte';
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

class _ShoppingStickyHeader extends StatelessWidget {
  const _ShoppingStickyHeader({
    required this.weekLabel,
    required this.onPrevious,
    required this.onNext,
    required this.showListControls,
    required this.plannedRecipeCount,
    required this.checkedCount,
    required this.totalCount,
    required this.viewMode,
    required this.onViewModeChanged,
  });

  final String weekLabel;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool showListControls;
  final int plannedRecipeCount;
  final int checkedCount;
  final int totalCount;
  final _ShoppingViewMode viewMode;
  final ValueChanged<_ShoppingViewMode> onViewModeChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.97),
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.72),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ShoppingWeekHeader(
                label: weekLabel,
                onPrevious: onPrevious,
                onNext: onNext,
              ),
              if (showListControls) ...[
                const SizedBox(height: 6),
                _ShoppingSummary(
                  plannedRecipeCount: plannedRecipeCount,
                  checkedCount: checkedCount,
                  totalCount: totalCount,
                ),
                const SizedBox(height: 8),
                _ShoppingViewSelector(
                  value: viewMode,
                  onChanged: onViewModeChanged,
                ),
              ],
            ],
          ),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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

class _ShoppingViewSelector extends StatelessWidget {
  const _ShoppingViewSelector({required this.value, required this.onChanged});

  final _ShoppingViewMode value;
  final ValueChanged<_ShoppingViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_ShoppingViewMode>(
      segments: const [
        ButtonSegment(
          value: _ShoppingViewMode.combined,
          icon: Icon(Icons.format_list_bulleted_rounded),
          label: Text('Alles'),
        ),
        ButtonSegment(
          value: _ShoppingViewMode.byRecipe,
          icon: Icon(Icons.menu_book_outlined),
          label: Text('Rezept'),
        ),
        ButtonSegment(
          value: _ShoppingViewMode.byDay,
          icon: Icon(Icons.calendar_today_outlined),
          label: Text('Tag'),
        ),
      ],
      selected: {value},
      onSelectionChanged: (selection) => onChanged(selection.single),
      showSelectedIcon: false,
    );
  }
}

class _ShoppingGroupSection extends StatelessWidget {
  const _ShoppingGroupSection({
    required this.group,
    required this.checkedItemKeys,
    required this.onChanged,
  });

  final _ShoppingGroup group;
  final Set<String> checkedItemKeys;
  final void Function(String key, bool? value) onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.65),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(group.title, style: Theme.of(context).textTheme.titleSmall),
              if (group.subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  group.subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 4),
              for (final item in group.items)
                _ShoppingItemTile(
                  item: item,
                  isChecked: checkedItemKeys.contains(item.key),
                  onChanged: (value) => onChanged(item.key, value),
                ),
            ],
          ),
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

  static List<_ShoppingItem> fromRecipesAndExtras(
    List<Recipe> recipes,
    List<String> extras,
  ) {
    final builders = <String, _ShoppingItemBuilder>{};

    for (final recipe in recipes) {
      for (final ingredient in recipe.ingredients) {
        final name = ingredient.name.trim();
        if (name.isEmpty) continue;
        if (ingredient.excludeFromShopping || _isHouseholdBasic(name)) {
          continue;
        }
        final unit = ingredient.unit.trim();
        final key = '${name.toLowerCase()}|${unit.toLowerCase()}';
        final builder = builders.putIfAbsent(
          key,
          () => _ShoppingItemBuilder(name: name, unit: unit),
        );
        builder.add(ingredient.quantity.trim(), recipe.title);
      }
    }

    for (final extra in extras) {
      final name = extra.trim();
      if (name.isEmpty) continue;
      final key = 'extra|${name.toLowerCase()}';
      builders.putIfAbsent(
        key,
        () => _ShoppingItemBuilder(name: name, unit: ''),
      );
    }

    final items = builders.entries
        .map((entry) => entry.value.build(entry.key))
        .toList();
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  static bool _isHouseholdBasic(String name) {
    final normalized = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
        .trim();
    return const {
      'water',
      'boiling water',
      'tap water',
      'cold water',
      'hot water',
      'ice',
      'wasser',
      'kochendes wasser',
      'leitungswasser',
      'kaltes wasser',
      'heisses wasser',
      'heißes wasser',
      'eis',
    }.contains(normalized);
  }
}

class _ShoppingGroup {
  const _ShoppingGroup({
    required this.title,
    required this.items,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<_ShoppingItem> items;
}

extension _ScopedShoppingItems on List<_ShoppingItem> {
  List<_ShoppingItem> scoped(String scope) {
    return [
      for (final item in this)
        _ShoppingItem(
          key: '$scope::${item.key}',
          name: item.name,
          quantityLabel: item.quantityLabel,
          sources: item.sources,
        ),
    ];
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
