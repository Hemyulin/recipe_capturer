import 'package:flutter/material.dart';
import 'package:cookbuk/data/meal_plan_repository.dart';
import 'package:cookbuk/data/recipe_repository.dart';
import 'package:cookbuk/domain/meal_plan_slot.dart';
import 'package:cookbuk/domain/recipe.dart';
import 'package:cookbuk/ui/widgets/meal_choice_sheet.dart';
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
  late DateTime _weekStart = _startOfWeek(DateTime.now());
  late DateTime _selectedDate = _dateOnly(DateTime.now());
  bool _isLoading = true;

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 6));

  @override
  void initState() {
    super.initState();
    _loadWeek();
  }

  Future<void> _loadWeek() async {
    setState(() => _isLoading = true);
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
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showPlanError('Wochenplan konnte nicht geladen werden.');
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
    } catch (_) {
      if (!mounted) return;
      setState(() => _slotValues[key] = previousValue);
      _showPlanError('Plan konnte nicht gespeichert werden.');
    }
  }

  Future<void> _clearSlot(DateTime date, String meal) async {
    final key = _slotKey(date, meal);
    final previousValue = _slotValues[key];
    setState(() => _slotValues[key] = null);

    try {
      await widget.mealPlanRepo.setEmpty(date: date, meal: meal);
    } catch (_) {
      if (!mounted) return;
      setState(() => _slotValues[key] = previousValue);
      _showPlanError('Plan konnte nicht gespeichert werden.');
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

  void _showPlanError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
          IconButton(
            onPressed: _showCurrentWeek,
            icon: const Icon(Icons.today_outlined),
            tooltip: 'Diese Woche',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadWeek,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            _WeekHeader(
              label: _weekLabel(_weekStart, _weekEnd),
              onPrevious: () => _moveWeek(-1),
              onNext: () => _moveWeek(1),
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _WeekDayStrip(
                days: days,
                selectedDate: _selectedDate,
                meals: _meals,
                slotValueFor: _slotValue,
                onSelectDate: (date) => setState(() => _selectedDate = date),
              ),
              const SizedBox(height: 18),
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
                onChooseMeal: (meal) => _chooseSlot(_selectedDate, meal),
                onClearMeal: (meal) => _clearSlot(_selectedDate, meal),
              ),
            ],
          ],
        ),
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

class _WeekDayStrip extends StatelessWidget {
  const _WeekDayStrip({
    required this.days,
    required this.selectedDate,
    required this.meals,
    required this.slotValueFor,
    required this.onSelectDate,
  });

  final List<DateTime> days;
  final DateTime selectedDate;
  final List<_MealInfo> meals;
  final String? Function(DateTime date, String meal) slotValueFor;
  final void Function(DateTime date) onSelectDate;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: Row(
        children: [
          for (final day in days) ...[
            Expanded(
              child: _WeekDayChip(
                date: day,
                isSelected: _isSameDate(day, selectedDate),
                meals: meals,
                slotValueFor: (meal) => slotValueFor(day, meal),
                onTap: () => onSelectDate(day),
              ),
            ),
            if (day != days.last) const SizedBox(width: 4),
          ],
        ],
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
    required this.onChooseMeal,
    required this.onClearMeal,
  });

  final DateTime date;
  final List<_MealInfo> meals;
  final Recipe? Function(String meal) recipeForMeal;
  final bool Function(String meal) isLeftoversForMeal;
  final void Function(String meal) onChooseMeal;
  final void Function(String meal) onClearMeal;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final meal in meals) ...[
          _WeekMealCard(
            meal: meal,
            recipe: recipeForMeal(meal.id),
            isLeftovers: isLeftoversForMeal(meal.id),
            onTap: () => onChooseMeal(meal.id),
            onClear: () => onClearMeal(meal.id),
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
    required this.onTap,
    required this.onClear,
  });

  final _MealInfo meal;
  final Recipe? recipe;
  final bool isLeftovers;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final imagePath = isLeftovers
        ? MealChoiceSheet.leftoversImagePath
        : recipe?.mainImagePath;
    final isPlanned = recipe != null || isLeftovers;

    return Card(
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
                  width: 74,
                  height: 74,
                  child: isPlanned
                      ? RecipeImage(
                          path: imagePath,
                          placeholderSeed: recipe?.id ?? meal.id,
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
                        Icon(meal.icon, size: 17, color: colorScheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          meal.label,
                          style: Theme.of(context).textTheme.titleSmall,
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
              if (isPlanned)
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Mahlzeit leeren',
                )
              else
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.add_rounded),
                ),
            ],
          ),
        ),
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
