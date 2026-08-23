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
    });
    await _loadWeek();
  }

  Future<void> _showCurrentWeek() async {
    setState(() => _weekStart = _startOfWeek(DateTime.now()));
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
            const SizedBox(height: 12),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              for (final day in days) ...[
                _DayPlanCard(
                  date: day,
                  meals: _meals,
                  recipeForMeal: (meal) => _recipeById(_slotValue(day, meal)),
                  isLeftoversForMeal: (meal) =>
                      _slotValue(day, meal) == MealChoiceSheet.leftoversValue,
                  onChooseMeal: (meal) => _chooseSlot(day, meal),
                  onClearMeal: (meal) => _clearSlot(day, meal),
                ),
                const SizedBox(height: 12),
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

class _DayPlanCard extends StatelessWidget {
  const _DayPlanCard({
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
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final isToday = _isSameDate(date, DateTime.now());

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${_weekdayLabel(date)} ${_dateLabel(date)}',
                    style: textTheme.titleMedium,
                  ),
                ),
                if (isToday)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'Heute',
                      style: textTheme.labelMedium?.copyWith(
                        color: colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          for (final meal in meals)
            _WeekMealRow(
              meal: meal,
              recipe: recipeForMeal(meal.id),
              isLeftovers: isLeftoversForMeal(meal.id),
              onTap: () => onChooseMeal(meal.id),
              onClear: () => onClearMeal(meal.id),
            ),
        ],
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
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.';
  }
}

class _WeekMealRow extends StatelessWidget {
  const _WeekMealRow({
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

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 8, 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 46,
                height: 46,
                child: isPlanned
                    ? RecipeImage(
                        path: imagePath,
                        placeholderSeed: recipe?.id ?? meal.id,
                      )
                    : UnplannedMealImage(title: meal.label),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(meal.icon, size: 15, color: colorScheme.primary),
                      const SizedBox(width: 5),
                      Text(
                        meal.label,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isLeftovers ? 'Reste' : recipe?.title ?? 'Nichts geplant',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(Icons.add_rounded),
              ),
          ],
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
