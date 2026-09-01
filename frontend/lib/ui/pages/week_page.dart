import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cookbuk/data/meal_plan_repository.dart';
import 'package:cookbuk/data/recipe_repository.dart';
import 'package:cookbuk/domain/meal_plan_slot.dart';
import 'package:cookbuk/domain/recipe.dart';
import 'package:cookbuk/ui/widgets/backend_connection_icon.dart';
import 'package:cookbuk/ui/widgets/meal_choice_sheet.dart';
import 'package:cookbuk/ui/widgets/meal_extras_sheet.dart';
import 'package:cookbuk/ui/widgets/meal_plan_sync_banner.dart';
import 'package:cookbuk/ui/widgets/load_state_view.dart';
import 'package:cookbuk/ui/widgets/recipe_image.dart';

class WeekPage extends StatefulWidget {
  const WeekPage({super.key, required this.repo, required this.mealPlanRepo});

  final RecipeRepository repo;
  final MealPlanRepository mealPlanRepo;

  @override
  State<WeekPage> createState() => _WeekPageState();
}

class _WeekPageState extends State<WeekPage> {
  static const _meals = [
    _MealInfo(
      id: 'breakfast',
      label: 'Frühstück',
      icon: Icons.wb_sunny_outlined,
    ),
    _MealInfo(
      id: 'lunch',
      label: 'Mittagessen',
      icon: Icons.light_mode_outlined,
    ),
    _MealInfo(
      id: 'dinner',
      label: 'Abendessen',
      icon: Icons.nights_stay_outlined,
    ),
  ];

  List<Recipe> _recipes = [];
  Map<String, String?> _slotValues = {};
  Map<String, List<String>> _slotExtras = {};
  Map<String, List<String>> _slotRecipeExtraIds = {};
  late DateTime _weekStart = _startOfWeek(DateTime.now());
  late DateTime _selectedDate = _dateOnly(DateTime.now());
  MealPlanSyncStatus _syncStatus = MealPlanSyncStatus.idle;
  StreamSubscription<MealPlanSyncStatus>? _syncStatusSubscription;
  Timer? _hideSyncedStatusTimer;
  bool _isLoading = true;
  String? _loadError;

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 6));

  @override
  void initState() {
    super.initState();
    final syncNotifier = widget.mealPlanRepo;
    if (syncNotifier is MealPlanSyncNotifier) {
      final notifier = syncNotifier as MealPlanSyncNotifier;
      _syncStatus = notifier.syncStatus;
      _syncStatusSubscription = notifier.syncStatusChanges.listen(
        _handleSyncStatus,
      );
    }
    _loadWeek();
  }

  @override
  void dispose() {
    _hideSyncedStatusTimer?.cancel();
    _syncStatusSubscription?.cancel();
    super.dispose();
  }

  void _handleSyncStatus(MealPlanSyncStatus status) {
    if (!mounted) return;
    _hideSyncedStatusTimer?.cancel();
    setState(() => _syncStatus = status);

    if (status.phase == MealPlanSyncPhase.synced) {
      _hideSyncedStatusTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _syncStatus = MealPlanSyncStatus.idle);
      });
      unawaited(_loadWeek());
    }
  }

  Future<void> _loadWeek() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final recipes = await widget.repo.getAll();
      final slots = await widget.mealPlanRepo.getRange(
        from: _weekStart,
        to: _weekEnd,
      );
      if (!mounted) return;
      setState(() {
        _recipes = recipes;
        _slotValues = _slotValuesFrom(slots);
        _slotExtras = _slotExtrasFrom(slots);
        _slotRecipeExtraIds = _slotRecipeExtraIdsFrom(slots);
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
      _selectedDate = _weekStart;
    });
    await _loadWeek();
  }

  Future<void> _showCurrentWeek() async {
    setState(() {
      _weekStart = _startOfWeek(DateTime.now());
      _selectedDate = _dateOnly(DateTime.now());
    });
    await _loadWeek();
  }

  Recipe? _recipeById(String? id) {
    if (id == null) return null;
    for (final recipe in _recipes) {
      if (recipe.id == id) return recipe;
    }
    return null;
  }

  String? _slotValue(DateTime date, String meal) {
    return _slotValues[_slotKey(date, meal)];
  }

  List<String> _extrasValue(DateTime date, String meal) {
    return _slotExtras[_slotKey(date, meal)] ?? const [];
  }

  List<String> _recipeExtraIdsValue(DateTime date, String meal) {
    return _slotRecipeExtraIds[_slotKey(date, meal)] ?? const [];
  }

  Future<void> _chooseSlot(DateTime date, String meal) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => MealChoiceSheet(recipes: _recipes),
    );
    if (selected == null || !mounted) return;

    final key = _slotKey(date, meal);
    final previousValue = _slotValues[key];
    setState(() => _slotValues[key] = selected);

    try {
      if (selected == MealChoiceSheet.leftoversValue) {
        await widget.mealPlanRepo.setLeftovers(date: date, meal: meal);
      } else {
        await widget.mealPlanRepo.setRecipe(
          date: date,
          meal: meal,
          recipeId: selected,
        );
      }
    } catch (error) {
      if (!mounted) return;
      if (error is MealPlanQueuedException) {
        _showPlanMessage(error.userMessage);
        return;
      }
      setState(() => _slotValues[key] = previousValue);
      _showPlanMessage(_mealPlanErrorMessage(error));
    }
  }

  Future<void> _clearSlot(DateTime date, String meal) async {
    final key = _slotKey(date, meal);
    final previousValue = _slotValues[key];
    final previousExtras = _slotExtras[key] ?? const <String>[];
    final previousRecipeExtraIds = _slotRecipeExtraIds[key] ?? const <String>[];
    setState(() {
      _slotValues[key] = null;
      _slotExtras[key] = const [];
      _slotRecipeExtraIds[key] = const [];
    });

    try {
      await widget.mealPlanRepo.setEmpty(date: date, meal: meal);
    } catch (error) {
      if (!mounted) return;
      if (error is MealPlanQueuedException) {
        _showPlanMessage(error.userMessage);
        return;
      }
      setState(() {
        _slotValues[key] = previousValue;
        _slotExtras[key] = previousExtras;
        _slotRecipeExtraIds[key] = previousRecipeExtraIds;
      });
      _showPlanMessage(_mealPlanErrorMessage(error));
    }
  }

  Future<void> _editExtras(DateTime date, String meal) async {
    final selectedExtras = await showModalBottomSheet<MealExtrasResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => MealExtrasSheet(
        initialExtras: _extrasValue(date, meal),
        initialRecipeExtraIds: _recipeExtraIdsValue(date, meal),
        recipes: _recipes,
      ),
    );
    if (selectedExtras == null || !mounted) return;

    final key = _slotKey(date, meal);
    final previousExtras = _slotExtras[key] ?? const <String>[];
    final previousRecipeIds = _slotRecipeExtraIds[key] ?? const <String>[];
    setState(() {
      _slotExtras[key] = selectedExtras.extras;
      _slotRecipeExtraIds[key] = selectedExtras.recipeExtraIds;
    });

    try {
      await widget.mealPlanRepo.setExtras(
        date: date,
        meal: meal,
        extras: selectedExtras.extras,
        recipeExtraIds: selectedExtras.recipeExtraIds,
      );
    } catch (error) {
      if (!mounted) return;
      if (error is MealPlanQueuedException) {
        _showPlanMessage(error.userMessage);
        return;
      }
      setState(() {
        _slotExtras[key] = previousExtras;
        _slotRecipeExtraIds[key] = previousRecipeIds;
      });
      _showPlanMessage(_mealPlanErrorMessage(error));
    }
  }

  Map<String, String?> _slotValuesFrom(List<MealPlanSlot> slots) {
    return {
      for (final slot in slots)
        _slotKey(slot.plannedFor, slot.meal): slot.isLeftovers
            ? MealChoiceSheet.leftoversValue
            : slot.isRecipe
            ? slot.recipeId
            : null,
    };
  }

  Map<String, List<String>> _slotExtrasFrom(List<MealPlanSlot> slots) {
    return {
      for (final slot in slots)
        _slotKey(slot.plannedFor, slot.meal): slot.extras,
    };
  }

  Map<String, List<String>> _slotRecipeExtraIdsFrom(List<MealPlanSlot> slots) {
    return {
      for (final slot in slots)
        _slotKey(slot.plannedFor, slot.meal): slot.recipeExtraIds,
    };
  }

  List<String> _extraLabels(DateTime date, String meal) {
    return [
      for (final id in _recipeExtraIdsValue(date, meal))
        if (_recipeById(id) != null) _recipeById(id)!.title,
      ..._extrasValue(date, meal),
    ];
  }

  void _showPlanMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _mealPlanErrorMessage(Object error) {
    if (error is MealPlanSaveException) return error.userMessage;
    return 'Plan konnte nicht gespeichert werden.';
  }

  @override
  Widget build(BuildContext context) {
    final days = List.generate(
      7,
      (index) => _weekStart.add(Duration(days: index)),
    );
    final selectedTitle =
        '${_weekdayName(_selectedDate)}, ${_longDate(_selectedDate)}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Woche'),
        actions: [
          BackendConnectionIcon(mealPlanRepo: widget.mealPlanRepo),
          IconButton(
            onPressed: _showCurrentWeek,
            icon: const Icon(Icons.today_outlined),
            tooltip: 'Diese Woche',
          ),
        ],
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: _loadWeek,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                16,
                4,
                16,
                _isLoading || _loadError != null ? 28 : 132,
              ),
              children: [
                _WeekHeader(
                  label: _weekLabel(_weekStart, _weekEnd),
                  onPrevious: () => _moveWeek(-1),
                  onNext: () => _moveWeek(1),
                ),
                const SizedBox(height: 8),
                MealPlanSyncBanner(status: _syncStatus),
                if (_syncStatus.isVisible) const SizedBox(height: 12),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: LoadStateView.loading(),
                  )
                else if (_loadError != null)
                  SizedBox(
                    height: 360,
                    child: LoadStateView.error(
                      title: 'Woche konnte nicht geladen werden',
                      message:
                          'Prüfe, ob der CookBuk-Backendserver läuft und dein Gerät im Tailscale ist.',
                      onRetry: _loadWeek,
                    ),
                  )
                else ...[
                  Text(
                    selectedTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  _SelectedDayPlan(
                    date: _selectedDate,
                    meals: _meals,
                    recipeForMeal: (meal) =>
                        _recipeById(_slotValue(_selectedDate, meal)),
                    isLeftoversForMeal: (meal) =>
                        _slotValue(_selectedDate, meal) ==
                        MealChoiceSheet.leftoversValue,
                    extrasForMeal: (meal) => _extraLabels(_selectedDate, meal),
                    onChooseMeal: (meal) => _chooseSlot(_selectedDate, meal),
                    onClearMeal: (meal) => _clearSlot(_selectedDate, meal),
                    onEditExtras: (meal) => _editExtras(_selectedDate, meal),
                  ),
                ],
              ],
            ),
          ),
          if (!_isLoading && _loadError == null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: SafeArea(
                top: false,
                child: _WeekDayStrip(
                  days: days,
                  selectedDate: _selectedDate,
                  meals: _meals,
                  slotValueFor: _slotValue,
                  onSelectDate: (date) => setState(() => _selectedDate = date),
                  onPreviousWeek: () => unawaited(_moveWeek(-1)),
                  onNextWeek: () => unawaited(_moveWeek(1)),
                ),
              ),
            ),
        ],
      ),
    );
  }

  static DateTime _startOfWeek(DateTime date) {
    final dateOnly = _dateOnly(date);
    return dateOnly.subtract(Duration(days: dateOnly.weekday - 1));
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static String _slotKey(DateTime date, String meal) {
    return '${_dateKey(date)}:$meal';
  }

  static String _dateKey(DateTime date) {
    return [
      date.year.toString().padLeft(4, '0'),
      date.month.toString().padLeft(2, '0'),
      date.day.toString().padLeft(2, '0'),
    ].join('-');
  }

  static String _weekLabel(DateTime start, DateTime end) {
    return '${_shortDate(start)} - ${_shortDate(end)}';
  }

  static String _shortDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.';
  }

  static String _longDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  static String _weekdayName(DateTime date) {
    const labels = [
      'Montag',
      'Dienstag',
      'Mittwoch',
      'Donnerstag',
      'Freitag',
      'Samstag',
      'Sonntag',
    ];
    return labels[date.weekday - 1];
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({
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

class _WeekDayStrip extends StatefulWidget {
  const _WeekDayStrip({
    required this.days,
    required this.selectedDate,
    required this.meals,
    required this.slotValueFor,
    required this.onSelectDate,
    required this.onPreviousWeek,
    required this.onNextWeek,
  });

  final List<DateTime> days;
  final DateTime selectedDate;
  final List<_MealInfo> meals;
  final String? Function(DateTime date, String meal) slotValueFor;
  final void Function(DateTime date) onSelectDate;
  final VoidCallback onPreviousWeek;
  final VoidCallback onNextWeek;

  @override
  State<_WeekDayStrip> createState() => _WeekDayStripState();
}

class _WeekDayStripState extends State<_WeekDayStrip> {
  double _dragDelta = 0;

  void _handleDragUpdate(DragUpdateDetails details) {
    _dragDelta += details.delta.dx;
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final shouldGoNext = _dragDelta < -48 || velocity < -450;
    final shouldGoPrevious = _dragDelta > 48 || velocity > 450;
    _dragDelta = 0;

    if (shouldGoNext) {
      widget.onNextWeek();
    } else if (shouldGoPrevious) {
      widget.onPreviousWeek();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: SizedBox(
        height: 84,
        child: Row(
          children: [
            for (final day in widget.days) ...[
              Expanded(
                child: _WeekDayChip(
                  date: day,
                  isSelected: _isSameDate(day, widget.selectedDate),
                  meals: widget.meals,
                  slotValueFor: (meal) => widget.slotValueFor(day, meal),
                  onTap: () => widget.onSelectDate(day),
                ),
              ),
              if (day != widget.days.last) const SizedBox(width: 4),
            ],
          ],
        ),
      ),
    );
  }

  static bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _WeekDayChip extends StatelessWidget {
  const _WeekDayChip({
    required this.date,
    required this.isSelected,
    required this.meals,
    required this.slotValueFor,
    required this.onTap,
  });

  final DateTime date;
  final bool isSelected;
  final List<_MealInfo> meals;
  final String? Function(String meal) slotValueFor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isToday = _isSameDate(date, DateTime.now());

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: isToday
            ? Border.all(color: colorScheme.onSurface, width: 2)
            : null,
      ),
      child: Padding(
        padding: EdgeInsets.all(isToday ? 2 : 0),
        child: Material(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _weekdayLabel(date),
                    style: textTheme.labelMedium?.copyWith(
                      color: isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _dateLabel(date),
                    style: textTheme.bodySmall?.copyWith(
                      color: isSelected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final meal in meals) ...[
                        _MealStatusDot(
                          value: slotValueFor(meal.id),
                          isSelectedDay: isSelected,
                        ),
                        if (meal != meals.last) const SizedBox(width: 3),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static String _weekdayLabel(DateTime date) {
    const labels = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    return labels[date.weekday - 1];
  }

  static String _dateLabel(DateTime date) {
    return date.day.toString().padLeft(2, '0');
  }
}

class _MealStatusDot extends StatelessWidget {
  const _MealStatusDot({required this.value, required this.isSelectedDay});

  final String? value;
  final bool isSelectedDay;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPlanned = value != null;
    final isLeftovers = value == MealChoiceSheet.leftoversValue;

    return SizedBox(
      width: 7,
      height: 7,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isPlanned
              ? isLeftovers
                    ? colorScheme.tertiary
                    : colorScheme.primary
              : Colors.transparent,
          border: Border.all(
            color: isSelectedDay
                ? colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                : colorScheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}

class _SelectedDayPlan extends StatelessWidget {
  const _SelectedDayPlan({
    required this.date,
    required this.meals,
    required this.recipeForMeal,
    required this.isLeftoversForMeal,
    required this.extrasForMeal,
    required this.onChooseMeal,
    required this.onClearMeal,
    required this.onEditExtras,
  });

  final DateTime date;
  final List<_MealInfo> meals;
  final Recipe? Function(String meal) recipeForMeal;
  final bool Function(String meal) isLeftoversForMeal;
  final List<String> Function(String meal) extrasForMeal;
  final void Function(String meal) onChooseMeal;
  final void Function(String meal) onClearMeal;
  final void Function(String meal) onEditExtras;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final meal in meals) ...[
          _WeekMealCard(
            meal: meal,
            recipe: recipeForMeal(meal.id),
            isLeftovers: isLeftoversForMeal(meal.id),
            extras: extrasForMeal(meal.id),
            onTap: () => onChooseMeal(meal.id),
            onChange: () => onChooseMeal(meal.id),
            onClear: () => onClearMeal(meal.id),
            onExtras: () => onEditExtras(meal.id),
          ),
          if (meal != meals.last) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _WeekMealCard extends StatelessWidget {
  const _WeekMealCard({
    required this.meal,
    this.recipe,
    required this.isLeftovers,
    this.extras = const [],
    required this.onTap,
    required this.onChange,
    required this.onClear,
    required this.onExtras,
  });

  final _MealInfo meal;
  final Recipe? recipe;
  final bool isLeftovers;
  final List<String> extras;
  final VoidCallback onTap;
  final VoidCallback onChange;
  final VoidCallback onClear;
  final VoidCallback onExtras;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentRecipe = recipe;
    final imagePath = isLeftovers
        ? MealChoiceSheet.leftoversImagePath
        : currentRecipe?.mainImagePath;
    final isPlanned = currentRecipe != null || isLeftovers;

    final card = Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: 86,
                  height: 86,
                  child: isPlanned
                      ? RecipeImage(
                          path: imagePath,
                          placeholderSeed: currentRecipe?.id ?? meal.id,
                          cacheKey: currentRecipe == null
                              ? null
                              : recipeImageCacheKey(currentRecipe),
                        )
                      : UnplannedMealImage(title: meal.label),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Icon(
                                meal.icon,
                                size: 17,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  meal.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _ExtrasButton(
                          onPressed: onExtras,
                          hasExtras: extras.isNotEmpty,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isLeftovers ? 'Reste' : recipe?.title ?? 'Nichts geplant',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    if (extras.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '+ ${extras.join(' · ')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (recipe?.totalTimeMinutes != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '${recipe!.totalTimeMinutes} min',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!isPlanned) return card;

    return _RevealableWeekMealCard(
      onChange: onChange,
      onClear: onClear,
      child: card,
    );
  }
}

class _RevealableWeekMealCard extends StatefulWidget {
  const _RevealableWeekMealCard({
    required this.child,
    required this.onChange,
    required this.onClear,
  });

  final Widget child;
  final VoidCallback onChange;
  final VoidCallback onClear;

  @override
  State<_RevealableWeekMealCard> createState() =>
      _RevealableWeekMealCardState();
}

class _RevealableWeekMealCardState extends State<_RevealableWeekMealCard> {
  static const double _actionWidth = 92;
  static const double _openThreshold = 42;

  double _dragOffset = 0;
  bool _dragStartedFromDeleteReveal = false;

  bool get _isDeleteRevealed => _dragOffset < -0.5;

  void _close() {
    if (!_isDeleteRevealed) return;
    setState(() => _dragOffset = 0);
  }

  void _handleDragStart(DragStartDetails details) {
    _dragStartedFromDeleteReveal = _isDeleteRevealed;
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset = (_dragOffset + details.delta.dx).clamp(
        -_actionWidth,
        _actionWidth,
      );
    });
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final shouldChange = _dragOffset > _openThreshold || velocity > 600;
    final shouldRevealDelete = _dragOffset < -_openThreshold || velocity < -600;

    if (_dragStartedFromDeleteReveal &&
        (velocity > 0 || _dragOffset >= -_openThreshold)) {
      setState(() => _dragOffset = 0);
      _dragStartedFromDeleteReveal = false;
      return;
    }

    _dragStartedFromDeleteReveal = false;

    setState(() {
      if (shouldRevealDelete) {
        _dragOffset = -_actionWidth;
      } else {
        _dragOffset = 0;
      }
    });

    if (shouldChange) {
      widget.onChange();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Positioned.fill(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _RevealAction(
                icon: Icons.swap_horiz_rounded,
                color: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
              ),
              const Spacer(),
              _RevealAction(
                icon: Icons.delete_outline,
                color: colorScheme.errorContainer,
                foregroundColor: colorScheme.onErrorContainer,
                onTap: () {
                  _close();
                  widget.onClear();
                },
              ),
            ],
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(_dragOffset, 0, 0),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _isDeleteRevealed ? _close : null,
            onHorizontalDragStart: _handleDragStart,
            onHorizontalDragUpdate: _handleDragUpdate,
            onHorizontalDragEnd: _handleDragEnd,
            child: widget.child,
          ),
        ),
      ],
    );
  }
}

class _RevealAction extends StatelessWidget {
  const _RevealAction({
    required this.icon,
    required this.color,
    required this.foregroundColor,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color foregroundColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _RevealableWeekMealCardState._actionWidth,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Icon(icon, color: foregroundColor),
        ),
      ),
    );
  }
}

class _ExtrasButton extends StatelessWidget {
  const _ExtrasButton({required this.onPressed, required this.hasExtras});

  final VoidCallback onPressed;
  final bool hasExtras;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Tooltip(
      message: 'Beilagen bearbeiten',
      child: IconButton.filledTonal(
        onPressed: onPressed,
        style: IconButton.styleFrom(
          fixedSize: const Size.square(38),
          minimumSize: const Size.square(38),
          padding: EdgeInsets.zero,
          foregroundColor: hasExtras
              ? colorScheme.onSecondaryContainer
              : colorScheme.onSurfaceVariant,
          backgroundColor: hasExtras
              ? colorScheme.secondaryContainer
              : colorScheme.surfaceContainerHighest,
        ),
        icon: const Icon(Icons.restaurant_menu_rounded, size: 18),
      ),
    );
  }
}

class _MealInfo {
  const _MealInfo({required this.id, required this.label, required this.icon});

  final String id;
  final String label;
  final IconData icon;
}
