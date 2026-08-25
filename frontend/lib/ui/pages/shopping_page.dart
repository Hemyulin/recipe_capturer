import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cookbuk/data/meal_plan_repository.dart';
import 'package:cookbuk/domain/meal_plan_slot.dart';
import 'package:cookbuk/data/recipe_repository.dart';
import 'package:cookbuk/data/shopping_knowledge_repository.dart';
import 'package:cookbuk/domain/recipe.dart';
import 'package:cookbuk/domain/shopping_knowledge.dart';
import 'package:cookbuk/ui/widgets/backend_connection_icon.dart';
import 'package:cookbuk/ui/widgets/load_state_view.dart';

enum _ShoppingSectionMode { list, items, stores }

enum _ShoppingViewMode { combined, byRecipe, byDay, byStore }

class _ShoppingKnowledgeSnapshot {
  const _ShoppingKnowledgeSnapshot({
    this.stores = const [],
    this.items = const [],
    this.manualItems = const [],
  });

  final List<ShoppingStore> stores;
  final List<ShoppingKnowledgeItem> items;
  final List<ManualShoppingItem> manualItems;
}

class ShoppingPage extends StatefulWidget {
  const ShoppingPage({
    super.key,
    required this.repo,
    required this.mealPlanRepo,
    this.shoppingRepo,
  });

  final RecipeRepository repo;
  final MealPlanRepository mealPlanRepo;
  final ShoppingKnowledgeRepository? shoppingRepo;

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
  List<ShoppingStore> _stores = [];
  List<ShoppingKnowledgeItem> _knowledgeItems = [];
  List<ManualShoppingItem> _manualItems = [];
  Set<String> _checkedItemKeys = {};
  int _plannedRecipeCount = 0;
  _ShoppingSectionMode _sectionMode = _ShoppingSectionMode.list;
  _ShoppingViewMode _viewMode = _ShoppingViewMode.combined;
  String _knowledgeQuery = '';
  String? _knowledgeStoreFilterId;

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 6));
  List<_ShoppingItem> get _visibleItems => switch (_viewMode) {
    _ShoppingViewMode.combined => _items,
    _ShoppingViewMode.byRecipe => [
      for (final group in _visibleGroups) ...group.items,
    ],
    _ShoppingViewMode.byDay => [
      for (final group in _visibleGroups) ...group.items,
    ],
    _ShoppingViewMode.byStore => [
      for (final group in _visibleGroups) ...group.items,
    ],
  };

  List<_ShoppingGroup> get _visibleGroups => switch (_viewMode) {
    _ShoppingViewMode.combined => const [],
    _ShoppingViewMode.byRecipe => _filteredGroups([
      ..._recipeGroups,
      if (_manualGroup() != null) _manualGroup()!,
    ]),
    _ShoppingViewMode.byDay => _filteredGroups([
      ..._dayGroups,
      if (_manualGroup() != null) _manualGroup()!,
    ]),
    _ShoppingViewMode.byStore => _filteredGroups(_storeGroupsFromItems(_items)),
  };

  List<ShoppingStore> get _activeStores =>
      _stores.where((store) => store.isActive).toList();

  _ShoppingGroup? _manualGroup() {
    final items = _ShoppingItem.fromManualItems(_manualItems);
    if (items.isEmpty) return null;
    return _ShoppingGroup(title: 'Manuell', items: items);
  }

  @override
  void initState() {
    super.initState();
    _loadList();
  }

  Future<void> _loadList() async {
    final weekStart = _weekStart;
    final weekEnd = _weekEnd;
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final coreResults = await Future.wait<Object>([
        widget.repo.getAll(),
        widget.mealPlanRepo.getRange(from: weekStart, to: weekEnd),
      ]);
      final recipes = coreResults[0] as List<Recipe>;
      final slots = coreResults[1] as List<MealPlanSlot>;

      if (!mounted) return;
      _applyShoppingList(
        weekStart: weekStart,
        recipes: recipes,
        slots: slots,
        shoppingKnowledge: const _ShoppingKnowledgeSnapshot(),
      );
      unawaited(_refreshShoppingKnowledge(recipes: recipes, slots: slots));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Backend nicht erreichbar.';
      });
    }
  }

  Future<void> _refreshShoppingKnowledge({
    required List<Recipe> recipes,
    required List<MealPlanSlot> slots,
  }) async {
    final weekStart = _weekStart;
    final shoppingKnowledge = await _loadShoppingKnowledge(weekStart);
    if (!mounted || weekStart != _weekStart) return;
    _applyShoppingList(
      weekStart: weekStart,
      recipes: recipes,
      slots: slots,
      shoppingKnowledge: shoppingKnowledge,
      keepLoadingState: false,
    );
  }

  Future<_ShoppingKnowledgeSnapshot> _loadShoppingKnowledge(
    DateTime weekStart,
  ) async {
    final shoppingRepo = widget.shoppingRepo;
    if (shoppingRepo == null) return const _ShoppingKnowledgeSnapshot();

    try {
      final results = await Future.wait<Object>([
        shoppingRepo.getStores(),
        shoppingRepo.getItems(),
        shoppingRepo.getManualItems(weekStart: weekStart),
      ]);
      return _ShoppingKnowledgeSnapshot(
        stores: results[0] as List<ShoppingStore>,
        items: results[1] as List<ShoppingKnowledgeItem>,
        manualItems: results[2] as List<ManualShoppingItem>,
      );
    } catch (_) {
      return const _ShoppingKnowledgeSnapshot();
    }
  }

  void _applyShoppingList({
    required DateTime weekStart,
    required List<Recipe> recipes,
    required List<MealPlanSlot> slots,
    required _ShoppingKnowledgeSnapshot shoppingKnowledge,
    bool keepLoadingState = true,
  }) {
    final stores = shoppingKnowledge.stores;
    final knowledgeItems = shoppingKnowledge.items;
    final manualItems = shoppingKnowledge.manualItems;
    final knowledgeByName = {
      for (final item in knowledgeItems) item.normalizedName: item,
    };
    final recipeById = {for (final recipe in recipes) recipe.id: recipe};
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
    final items = _ShoppingItem.fromRecipesAndExtras(
      [...plannedRecipes, ...sideRecipes],
      extras,
      knowledgeByName,
      manualItems,
    );
    final recipeGroups = _recipeGroupsFromSlots(
      sortedSlots,
      recipeById,
      knowledgeByName,
    );
    final dayGroups = _dayGroupsFromSlots(
      weekStart,
      sortedSlots,
      recipeById,
      knowledgeByName,
    );
    final visibleKeys = {
      for (final item in items) item.key,
      for (final group in recipeGroups)
        for (final item in group.items) item.key,
      for (final group in dayGroups)
        for (final item in group.items) item.key,
    };

    setState(() {
      _plannedRecipeCount = plannedRecipes.length;
      _stores = stores;
      _knowledgeItems = knowledgeItems;
      _manualItems = manualItems;
      _items = items;
      _recipeGroups = recipeGroups;
      _dayGroups = dayGroups;
      _checkedItemKeys = _checkedItemKeys.intersection(visibleKeys);
      if (keepLoadingState) _isLoading = false;
    });
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

  Future<void> _runShoppingAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_shoppingActionErrorMessage(error))),
      );
    }
  }

  String _shoppingActionErrorMessage(Object error) {
    if (error is RecipeSaveException) return error.userMessage;
    return 'Einkaufswissen konnte nicht gespeichert werden. Ist der Pi aktuell?';
  }

  Future<void> _showShoppingKnowledgeMenu() async {
    final selected = await showModalBottomSheet<_ShoppingSectionMode>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _ShoppingKnowledgeMenuSheet(),
    );
    if (selected == null || !mounted) return;
    setState(() => _sectionMode = selected);
  }

  Future<void> _showViewModeSheet() async {
    final selected = await showModalBottomSheet<_ShoppingViewMode>(
      context: context,
      showDragHandle: true,
      builder: (context) => _ShoppingViewModeSheet(value: _viewMode),
    );
    if (selected == null || !mounted) return;
    setState(() => _viewMode = selected);
  }

  Future<void> _showAddStoreSheet() async {
    if (widget.shoppingRepo == null) return;
    final name = await _showTextInputSheet(
      title: 'Laden hinzufügen',
      label: 'Name',
    );
    if (name == null || name.trim().isEmpty) return;
    await _runShoppingAction(() async {
      await widget.shoppingRepo!.addStore(name.trim());
      await _loadList();
    });
  }

  Future<void> _showAddKnowledgeItemSheet({String? initialStoreId}) async {
    if (widget.shoppingRepo == null) return;
    final result = await showModalBottomSheet<_ShoppingItemEditResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ShoppingItemEditSheet(
        title: 'Artikel hinzufügen',
        stores: _activeStores,
        initialStoreId: initialStoreId,
      ),
    );
    if (result == null || result.name.trim().isEmpty) return;
    await _runShoppingAction(() async {
      await widget.shoppingRepo!.addItem(
        name: result.name.trim(),
        storeId: result.storeId,
      );
      await _loadList();
    });
  }

  Future<void> _showEditKnowledgeItemSheet(ShoppingKnowledgeItem item) async {
    if (widget.shoppingRepo == null) return;
    final result = await showModalBottomSheet<_ShoppingItemEditResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ShoppingItemEditSheet(
        title: 'Artikel bearbeiten',
        stores: _activeStores,
        initialName: item.name,
        initialStoreId: item.storeId,
      ),
    );
    if (result == null || result.name.trim().isEmpty) return;
    await _runShoppingAction(() async {
      await widget.shoppingRepo!.updateItem(
        id: item.id,
        name: result.name.trim(),
        storeId: result.storeId,
      );
      await _loadList();
    });
  }

  Future<void> _showEditStoreSheet(ShoppingStore store) async {
    if (widget.shoppingRepo == null) return;
    final name = await _showTextInputSheet(
      title: 'Laden umbenennen',
      label: 'Name',
      initialValue: store.name,
    );
    if (name == null || name.trim().isEmpty) return;
    await _runShoppingAction(() async {
      await widget.shoppingRepo!.updateStore(id: store.id, name: name.trim());
      await _loadList();
    });
  }

  Future<void> _deactivateStore(ShoppingStore store) async {
    if (widget.shoppingRepo == null) return;
    await _runShoppingAction(() async {
      await widget.shoppingRepo!.deleteStore(store.id);
      await _loadList();
    });
  }

  Future<void> _showAddManualItemSheet() async {
    if (widget.shoppingRepo == null) return;
    final result = await showModalBottomSheet<_ManualShoppingItemEditResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _ManualShoppingItemEditSheet(
        stores: _activeStores,
        knownItems: _knowledgeItems,
      ),
    );
    if (result == null || result.name.trim().isEmpty) return;
    await _runShoppingAction(() async {
      await widget.shoppingRepo!.addManualItem(
        weekStart: _weekStart,
        name: result.name.trim(),
        quantityLabel: result.quantityLabel.trim(),
        storeId: result.storeId,
        rememberStore: result.rememberStore,
      );
      await _loadList();
    });
  }

  Future<void> _deleteManualItem(String id) async {
    if (widget.shoppingRepo == null) return;
    await _runShoppingAction(() async {
      await widget.shoppingRepo!.deleteManualItem(id);
      await _loadList();
    });
  }

  Future<String?> _showTextInputSheet({
    required String title,
    required String label,
    String initialValue = '',
  }) {
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => _TextInputSheet(
        title: title,
        label: label,
        initialValue: initialValue,
      ),
    );
  }

  Future<void> _copyShoppingList() async {
    if (_visibleItems.isEmpty) return;

    final text = _viewMode == _ShoppingViewMode.combined
        ? _visibleItems.map((item) => item.title).join('\n')
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
        leading: _sectionMode == _ShoppingSectionMode.list
            ? null
            : IconButton(
                onPressed: () =>
                    setState(() => _sectionMode = _ShoppingSectionMode.list),
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Zur Einkaufsliste',
              ),
        title: Text(_sectionTitle(_sectionMode)),
        actions: [
          BackendConnectionIcon(mealPlanRepo: widget.mealPlanRepo),
          if (_sectionMode == _ShoppingSectionMode.list &&
              widget.shoppingRepo != null)
            IconButton(
              onPressed: _showShoppingKnowledgeMenu,
              icon: const Icon(Icons.storefront_outlined),
              tooltip: 'Einkaufswissen',
            ),
          if (_sectionMode == _ShoppingSectionMode.list &&
              widget.shoppingRepo != null)
            IconButton(
              onPressed: _showAddManualItemSheet,
              icon: const Icon(Icons.add_shopping_cart_rounded),
              tooltip: 'Artikel hinzufügen',
            ),
          if (_sectionMode == _ShoppingSectionMode.items)
            IconButton(
              onPressed: () => _showAddKnowledgeItemSheet(),
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Artikel hinzufügen',
            ),
          if (_sectionMode == _ShoppingSectionMode.stores)
            IconButton(
              onPressed: _showAddStoreSheet,
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Laden hinzufügen',
            ),
          if (_sectionMode == _ShoppingSectionMode.list)
            IconButton(
              onPressed: _items.isEmpty ? null : _copyShoppingList,
              icon: const Icon(Icons.content_copy_rounded),
              tooltip: 'Einkaufsliste kopieren',
            ),
          if (_sectionMode == _ShoppingSectionMode.list)
            IconButton(
              onPressed: _showCurrentWeek,
              icon: const Icon(Icons.today_outlined),
              tooltip: 'Diese Woche',
            ),
        ],
      ),
      body: Column(
        children: [
          if (_sectionMode == _ShoppingSectionMode.list)
            _ShoppingStickyHeader(
              weekLabel: _weekLabel(_weekStart, _weekEnd),
              onPrevious: () => _moveWeek(-1),
              onNext: () => _moveWeek(1),
              showListControls: true,
              plannedRecipeCount: _plannedRecipeCount,
              checkedCount: checkedVisibleCount,
              totalCount: visibleItems.length,
              viewMode: _viewMode,
              hasShoppingItems: hasShoppingItems,
              onSelectViewMode: _showViewModeSheet,
            ),
          Expanded(
            child: switch (_sectionMode) {
              _ShoppingSectionMode.list => _buildShoppingListBody(visibleItems),
              _ShoppingSectionMode.items => _ShoppingKnowledgeItemsView(
                items: _filteredKnowledgeItems(),
                stores: _activeStores,
                selectedStoreId: _knowledgeStoreFilterId,
                query: _knowledgeQuery,
                onQueryChanged: (value) =>
                    setState(() => _knowledgeQuery = value),
                onStoreFilterChanged: (value) =>
                    setState(() => _knowledgeStoreFilterId = value),
                onAddItem: () => _showAddKnowledgeItemSheet(),
                onEditItem: _showEditKnowledgeItemSheet,
              ),
              _ShoppingSectionMode.stores => _ShoppingStoresView(
                stores: _activeStores,
                items: _knowledgeItems,
                onAddStore: _showAddStoreSheet,
                onEditStore: _showEditStoreSheet,
                onDeactivateStore: _deactivateStore,
                onAddItemForStore: (store) =>
                    _showAddKnowledgeItemSheet(initialStoreId: store.id),
              ),
            },
          ),
        ],
      ),
    );
  }

  static String _sectionTitle(_ShoppingSectionMode sectionMode) {
    return switch (sectionMode) {
      _ShoppingSectionMode.list => 'Einkauf',
      _ShoppingSectionMode.items => 'Artikel',
      _ShoppingSectionMode.stores => 'Läden',
    };
  }

  Widget _buildShoppingListBody(List<_ShoppingItem> visibleItems) {
    return RefreshIndicator(
      onRefresh: _loadList,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          if (_isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: LoadStateView.loading(),
              ),
            )
          else if (_loadError != null)
            SliverFillRemaining(
              hasScrollBody: false,
              child: LoadStateView.error(
                title: 'Einkaufsliste konnte nicht geladen werden',
                message:
                    'Prüfe, ob der CookBuk-Backendserver läuft und dein Gerät im Tailscale ist.',
                onRetry: _loadList,
              ),
            )
          else if (_items.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _EmptyShoppingList(onRefresh: _loadList),
            )
          else if (_viewMode == _ShoppingViewMode.combined)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              sliver: SliverList.builder(
                itemCount: visibleItems.length,
                itemBuilder: (context, index) {
                  final item = visibleItems[index];
                  return _ShoppingItemTile(
                    item: item,
                    isChecked: _checkedItemKeys.contains(item.key),
                    onChanged: (value) => _toggleItem(item.key, value),
                    onDelete: item.manualItemId == null
                        ? null
                        : () => _deleteManualItem(item.manualItemId!),
                  );
                },
              ),
            )
          else
            ..._groupedShoppingSlivers(_visibleGroups),
        ],
      ),
    );
  }

  List<Widget> _groupedShoppingSlivers(List<_ShoppingGroup> groups) {
    return [
      const SliverToBoxAdapter(child: SizedBox(height: 12)),
      for (final group in groups)
        SliverMainAxisGroup(
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _ShoppingGroupHeaderDelegate(group: group),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              sliver: SliverList.builder(
                itemCount: group.items.length,
                itemBuilder: (context, index) {
                  final item = group.items[index];
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      border: Border(
                        left: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.outlineVariant.withValues(alpha: 0.65),
                        ),
                        right: BorderSide(
                          color: Theme.of(
                            context,
                          ).colorScheme.outlineVariant.withValues(alpha: 0.65),
                        ),
                        bottom: index == group.items.length - 1
                            ? BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outlineVariant
                                    .withValues(alpha: 0.65),
                              )
                            : BorderSide.none,
                      ),
                    ),
                    child: _ShoppingItemTile(
                      item: item,
                      isChecked: _checkedItemKeys.contains(item.key),
                      onChanged: (value) => _toggleItem(item.key, value),
                      onDelete: item.manualItemId == null
                          ? null
                          : () => _deleteManualItem(item.manualItemId!),
                    ),
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 6)),
          ],
        ),
      const SliverToBoxAdapter(child: SizedBox(height: 20)),
    ];
  }

  List<ShoppingKnowledgeItem> _filteredKnowledgeItems() {
    final query = _knowledgeQuery.trim().toLowerCase();
    return _knowledgeItems.where((item) {
      if (_knowledgeStoreFilterId == _withoutStoreFilterId) {
        if (item.storeId != null) return false;
      } else if (_knowledgeStoreFilterId != null &&
          item.storeId != _knowledgeStoreFilterId) {
        return false;
      }
      if (query.isEmpty) return true;
      return item.name.toLowerCase().contains(query) ||
          (item.storeName ?? '').toLowerCase().contains(query);
    }).toList();
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
    Map<String, ShoppingKnowledgeItem> knowledgeByName,
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
            knowledgeByName,
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
          knowledgeByName,
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
        knowledgeByName,
        const [],
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
    Map<String, ShoppingKnowledgeItem> knowledgeByName,
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
        knowledgeByName,
        const [],
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

  List<_ShoppingGroup> _filteredGroups(List<_ShoppingGroup> groups) {
    return groups.where((group) => group.items.isNotEmpty).toList();
  }

  static List<_ShoppingGroup> _storeGroupsFromItems(List<_ShoppingItem> items) {
    final grouped = <String, List<_ShoppingItem>>{};
    final labels = <String, String>{};
    for (final item in items) {
      final key = item.storeId ?? _withoutStoreFilterId;
      grouped.putIfAbsent(key, () => []).add(item);
      labels[key] = item.storeName ?? 'Noch ohne Laden';
    }

    final groups = [
      for (final entry in grouped.entries)
        _ShoppingGroup(title: labels[entry.key]!, items: entry.value),
    ];
    groups.sort((a, b) {
      if (a.title == 'Noch ohne Laden') return 1;
      if (b.title == 'Noch ohne Laden') return -1;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return groups;
  }
}

const _withoutStoreFilterId = '__without_store__';

class _ShoppingKnowledgeItemsView extends StatelessWidget {
  const _ShoppingKnowledgeItemsView({
    required this.items,
    required this.stores,
    required this.selectedStoreId,
    required this.query,
    required this.onQueryChanged,
    required this.onStoreFilterChanged,
    required this.onAddItem,
    required this.onEditItem,
  });

  final List<ShoppingKnowledgeItem> items;
  final List<ShoppingStore> stores;
  final String? selectedStoreId;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String?> onStoreFilterChanged;
  final VoidCallback onAddItem;
  final ValueChanged<ShoppingKnowledgeItem> onEditItem;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      children: [
        TextField(
          decoration: const InputDecoration(
            hintText: 'Artikel oder Laden suchen',
            prefixIcon: Icon(Icons.search_rounded),
          ),
          onChanged: onQueryChanged,
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Alle Läden'),
                selected: selectedStoreId == null,
                onSelected: (_) => onStoreFilterChanged(null),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Ohne Laden'),
                selected: selectedStoreId == _withoutStoreFilterId,
                onSelected: (_) => onStoreFilterChanged(_withoutStoreFilterId),
              ),
              for (final store in stores) ...[
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(store.name),
                  selected: selectedStoreId == store.id,
                  onSelected: (_) => onStoreFilterChanged(store.id),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onAddItem,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Artikel hinzufügen'),
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Text(
                query.trim().isEmpty ? 'Noch keine Artikel.' : 'Keine Treffer.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          for (final item in items)
            Card(
              child: ListTile(
                onTap: () => onEditItem(item),
                title: Text(item.name),
                subtitle: Text(item.storeName ?? 'Ohne Laden'),
                trailing: const Icon(Icons.chevron_right_rounded),
              ),
            ),
      ],
    );
  }
}

class _ShoppingStoresView extends StatelessWidget {
  const _ShoppingStoresView({
    required this.stores,
    required this.items,
    required this.onAddStore,
    required this.onEditStore,
    required this.onDeactivateStore,
    required this.onAddItemForStore,
  });

  final List<ShoppingStore> stores;
  final List<ShoppingKnowledgeItem> items;
  final VoidCallback onAddStore;
  final ValueChanged<ShoppingStore> onEditStore;
  final ValueChanged<ShoppingStore> onDeactivateStore;
  final ValueChanged<ShoppingStore> onAddItemForStore;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
      children: [
        OutlinedButton.icon(
          onPressed: onAddStore,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Laden hinzufügen'),
        ),
        const SizedBox(height: 12),
        if (stores.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Text(
                'Noch keine Läden.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          )
        else
          for (final store in stores)
            _StoreSection(
              store: store,
              items: items.where((item) => item.storeId == store.id).toList()
                ..sort(
                  (a, b) =>
                      a.name.toLowerCase().compareTo(b.name.toLowerCase()),
                ),
              onEdit: () => onEditStore(store),
              onDeactivate: () => onDeactivateStore(store),
              onAddItem: () => onAddItemForStore(store),
            ),
        if (items.any((item) => item.storeId == null)) ...[
          const SizedBox(height: 8),
          _StoreSection(
            title: 'Ohne Laden',
            items: items.where((item) => item.storeId == null).toList(),
          ),
        ],
      ],
    );
  }
}

class _StoreSection extends StatelessWidget {
  const _StoreSection({
    this.store,
    this.title,
    required this.items,
    this.onEdit,
    this.onDeactivate,
    this.onAddItem,
  });

  final ShoppingStore? store;
  final String? title;
  final List<ShoppingKnowledgeItem> items;
  final VoidCallback? onEdit;
  final VoidCallback? onDeactivate;
  final VoidCallback? onAddItem;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sectionTitle = store?.name ?? title ?? '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    sectionTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (onAddItem != null)
                  IconButton(
                    onPressed: onAddItem,
                    icon: const Icon(Icons.add_rounded),
                    tooltip: 'Artikel hinzufügen',
                  ),
                if (onEdit != null)
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Umbenennen',
                  ),
                if (onDeactivate != null)
                  IconButton(
                    onPressed: onDeactivate,
                    icon: const Icon(Icons.hide_source_outlined),
                    tooltip: 'Deaktivieren',
                  ),
              ],
            ),
            if (items.isEmpty)
              Text(
                'Noch keine Artikel.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else
              for (final item in items)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(item.name),
                ),
          ],
        ),
      ),
    );
  }
}

class _ShoppingItemEditResult {
  const _ShoppingItemEditResult({required this.name, this.storeId});

  final String name;
  final String? storeId;
}

class _ShoppingItemEditSheet extends StatefulWidget {
  const _ShoppingItemEditSheet({
    required this.title,
    required this.stores,
    this.initialName = '',
    this.initialStoreId,
  });

  final String title;
  final List<ShoppingStore> stores;
  final String initialName;
  final String? initialStoreId;

  @override
  State<_ShoppingItemEditSheet> createState() => _ShoppingItemEditSheetState();
}

class _ShoppingItemEditSheetState extends State<_ShoppingItemEditSheet> {
  late final TextEditingController _nameController = TextEditingController(
    text: widget.initialName,
  );
  late String? _storeId = widget.initialStoreId;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              autofocus: widget.initialName.isEmpty,
              decoration: const InputDecoration(labelText: 'Artikel'),
            ),
            const SizedBox(height: 12),
            _StoreDropdown(
              stores: widget.stores,
              value: _storeId,
              onChanged: (value) => setState(() => _storeId = value),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  _ShoppingItemEditResult(
                    name: _nameController.text,
                    storeId: _storeId,
                  ),
                ),
                child: const Text('Speichern'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualShoppingItemEditResult {
  const _ManualShoppingItemEditResult({
    required this.name,
    required this.quantityLabel,
    this.storeId,
    this.rememberStore = false,
  });

  final String name;
  final String quantityLabel;
  final String? storeId;
  final bool rememberStore;
}

class _ManualShoppingItemEditSheet extends StatefulWidget {
  const _ManualShoppingItemEditSheet({
    required this.stores,
    required this.knownItems,
  });

  final List<ShoppingStore> stores;
  final List<ShoppingKnowledgeItem> knownItems;

  @override
  State<_ManualShoppingItemEditSheet> createState() =>
      _ManualShoppingItemEditSheetState();
}

class _ManualShoppingItemEditSheetState
    extends State<_ManualShoppingItemEditSheet> {
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  String? _storeId;
  bool _rememberStore = false;

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _inferStore(String value) {
    final normalized = _ShoppingItem._normalizeName(value);
    ShoppingKnowledgeItem? known;
    for (final item in widget.knownItems) {
      if (item.normalizedName == normalized) {
        known = item;
        break;
      }
    }
    if (known == null || known.storeId == _storeId) return;
    final knownStoreId = known.storeId;
    setState(() => _storeId = knownStoreId);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Artikel hinzufügen',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Artikel'),
              onChanged: _inferStore,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _quantityController,
              decoration: const InputDecoration(labelText: 'Menge'),
            ),
            const SizedBox(height: 12),
            _StoreDropdown(
              stores: widget.stores,
              value: _storeId,
              onChanged: (value) => setState(() => _storeId = value),
            ),
            CheckboxListTile(
              value: _rememberStore,
              onChanged: (value) =>
                  setState(() => _rememberStore = value ?? false),
              contentPadding: EdgeInsets.zero,
              title: const Text('Immer hier kaufen'),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  _ManualShoppingItemEditResult(
                    name: _nameController.text,
                    quantityLabel: _quantityController.text,
                    storeId: _storeId,
                    rememberStore: _rememberStore,
                  ),
                ),
                child: const Text('Hinzufügen'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreDropdown extends StatelessWidget {
  const _StoreDropdown({
    required this.stores,
    required this.value,
    required this.onChanged,
  });

  final List<ShoppingStore> stores;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Normalerweise bei'),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('Ohne Laden')),
        for (final store in stores)
          DropdownMenuItem<String?>(value: store.id, child: Text(store.name)),
      ],
      onChanged: onChanged,
    );
  }
}

class _TextInputSheet extends StatefulWidget {
  const _TextInputSheet({
    required this.title,
    required this.label,
    this.initialValue = '',
  });

  final String title;
  final String label;
  final String initialValue;

  @override
  State<_TextInputSheet> createState() => _TextInputSheetState();
}

class _TextInputSheetState extends State<_TextInputSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: InputDecoration(labelText: widget.label),
              onSubmitted: (_) => Navigator.of(context).pop(_controller.text),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(_controller.text),
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
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
    required this.hasShoppingItems,
    required this.plannedRecipeCount,
    required this.checkedCount,
    required this.totalCount,
    required this.viewMode,
    required this.onSelectViewMode,
  });

  final String weekLabel;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool showListControls;
  final bool hasShoppingItems;
  final int plannedRecipeCount;
  final int checkedCount;
  final int totalCount;
  final _ShoppingViewMode viewMode;
  final VoidCallback onSelectViewMode;

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
              if (showListControls && hasShoppingItems) ...[
                const SizedBox(height: 6),
                _ShoppingSummary(
                  plannedRecipeCount: plannedRecipeCount,
                  checkedCount: checkedCount,
                  totalCount: totalCount,
                  viewMode: viewMode,
                  onSelectViewMode: onSelectViewMode,
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
    required this.viewMode,
    required this.onSelectViewMode,
  });

  final int plannedRecipeCount;
  final int checkedCount;
  final int totalCount;
  final _ShoppingViewMode viewMode;
  final VoidCallback onSelectViewMode;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    '$plannedRecipeCount Rezepte, $totalCount Zutaten',
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '$checkedCount/$totalCount',
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onSelectViewMode,
            icon: const Icon(Icons.view_list_rounded, size: 18),
            label: Text('Ansicht: ${_viewModeLabel(viewMode)}'),
          ),
        ],
      ),
    );
  }
}

class _ShoppingKnowledgeMenuSheet extends StatelessWidget {
  const _ShoppingKnowledgeMenuSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        children: [
          Text('Einkaufswissen', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.list_alt_rounded),
            title: const Text('Artikel'),
            subtitle: const Text('Wo kaufen wir was normalerweise?'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).pop(_ShoppingSectionMode.items),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.storefront_outlined),
            title: const Text('Läden'),
            subtitle: const Text('Was kaufen wir bei welchem Laden?'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).pop(_ShoppingSectionMode.stores),
          ),
        ],
      ),
    );
  }
}

class _ShoppingViewModeSheet extends StatelessWidget {
  const _ShoppingViewModeSheet({required this.value});

  final _ShoppingViewMode value;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        children: [
          Text('Ansicht', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          for (final mode in _ShoppingViewMode.values)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(_viewModeIcon(mode)),
              title: Text(_viewModeLabel(mode)),
              trailing: mode == value
                  ? const Icon(Icons.check_rounded)
                  : const SizedBox.shrink(),
              onTap: () => Navigator.of(context).pop(mode),
            ),
        ],
      ),
    );
  }
}

IconData _viewModeIcon(_ShoppingViewMode mode) {
  return switch (mode) {
    _ShoppingViewMode.combined => Icons.format_list_bulleted_rounded,
    _ShoppingViewMode.byRecipe => Icons.menu_book_outlined,
    _ShoppingViewMode.byDay => Icons.calendar_today_outlined,
    _ShoppingViewMode.byStore => Icons.storefront_outlined,
  };
}

String _viewModeLabel(_ShoppingViewMode mode) {
  return switch (mode) {
    _ShoppingViewMode.combined => 'Alles',
    _ShoppingViewMode.byRecipe => 'Nach Rezept',
    _ShoppingViewMode.byDay => 'Nach Tag',
    _ShoppingViewMode.byStore => 'Nach Laden',
  };
}

class _ShoppingGroupHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _ShoppingGroupHeaderDelegate({required this.group});

  final _ShoppingGroup group;

  @override
  double get minExtent => group.subtitle == null ? 52 : 68;

  @override
  double get maxExtent => minExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return _ShoppingGroupHeader(group: group);
  }

  @override
  bool shouldRebuild(covariant _ShoppingGroupHeaderDelegate oldDelegate) {
    return oldDelegate.group != group;
  }
}

class _ShoppingGroupHeader extends StatelessWidget {
  const _ShoppingGroupHeader({required this.group});

  final _ShoppingGroup group;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(color: colorScheme.surface),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(
              color: colorScheme.outlineVariant.withValues(alpha: 0.65),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                if (group.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    group.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
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
    this.onDelete,
  });

  final _ShoppingItem item;
  final bool isChecked;
  final ValueChanged<bool?> onChanged;
  final VoidCallback? onDelete;

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
      secondary: onDelete == null
          ? null
          : IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'Entfernen',
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
    this.storeId,
    this.storeName,
    this.manualItemId,
  });

  final String key;
  final String name;
  final String quantityLabel;
  final List<String> sources;
  final String? storeId;
  final String? storeName;
  final String? manualItemId;

  String get title {
    if (quantityLabel.isEmpty) return name;
    return '$quantityLabel $name';
  }

  static List<_ShoppingItem> fromRecipesAndExtras(
    List<Recipe> recipes,
    List<String> extras,
    Map<String, ShoppingKnowledgeItem> knowledgeByName,
    List<ManualShoppingItem> manualItems,
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
        final knowledge = knowledgeByName[_normalizeName(name)];
        final builder = builders.putIfAbsent(
          key,
          () => _ShoppingItemBuilder(
            name: name,
            unit: unit,
            storeId: knowledge?.storeId,
            storeName: knowledge?.storeName,
          ),
        );
        builder.add(ingredient.quantity.trim(), recipe.title);
      }
    }

    for (final extra in extras) {
      final name = extra.trim();
      if (name.isEmpty) continue;
      final key = 'extra|${name.toLowerCase()}';
      final knowledge = knowledgeByName[_normalizeName(name)];
      builders.putIfAbsent(
        key,
        () => _ShoppingItemBuilder(
          name: name,
          unit: '',
          storeId: knowledge?.storeId,
          storeName: knowledge?.storeName,
        ),
      );
    }

    for (final manualItem in manualItems) {
      final name = manualItem.name.trim();
      if (name.isEmpty) continue;
      final key = 'manual|${manualItem.id}';
      final builder = builders.putIfAbsent(
        key,
        () => _ShoppingItemBuilder(
          name: name,
          unit: '',
          storeId: manualItem.storeId,
          storeName: manualItem.storeName,
          manualItemId: manualItem.id,
        ),
      );
      builder.add(manualItem.quantityLabel.trim(), 'Manuell');
    }

    final items = builders.entries
        .map((entry) => entry.value.build(entry.key))
        .toList();
    items.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return items;
  }

  static List<_ShoppingItem> fromManualItems(
    List<ManualShoppingItem> manualItems,
  ) {
    return [
      for (final item in manualItems)
        _ShoppingItem(
          key: 'manual|${item.id}',
          name: item.name,
          quantityLabel: item.quantityLabel,
          sources: const ['Manuell'],
          storeId: item.storeId,
          storeName: item.storeName,
          manualItemId: item.id,
        ),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  static bool _isHouseholdBasic(String name) {
    final normalized = _normalizeName(name);
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

  static String _normalizeName(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
        .trim();
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
          storeId: item.storeId,
          storeName: item.storeName,
          manualItemId: item.manualItemId,
        ),
    ];
  }
}

class _ShoppingItemBuilder {
  _ShoppingItemBuilder({
    required this.name,
    required this.unit,
    this.storeId,
    this.storeName,
    this.manualItemId,
  });

  final String name;
  final String unit;
  final String? storeId;
  final String? storeName;
  final String? manualItemId;
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
      storeId: storeId,
      storeName: storeName,
      manualItemId: manualItemId,
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
