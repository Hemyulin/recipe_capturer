import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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

class TodayPage extends StatefulWidget {
  const TodayPage({super.key, required this.repo, required this.mealPlanRepo});

  final RecipeRepository repo;
  final MealPlanRepository mealPlanRepo;

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  List<Recipe> _recipes = [];
  List<MealPlanSlot> _upcomingMealSlots = [];
  final Map<String, String?> _mealRecipeIds = {};
  final Map<String, List<String>> _mealExtras = {};
  final Map<String, List<String>> _mealRecipeExtraIds = {};
  late final DateTime _today = _dateOnly(DateTime.now());
  MealPlanSyncStatus _syncStatus = MealPlanSyncStatus.idle;
  StreamSubscription<MealPlanSyncStatus>? _syncStatusSubscription;
  Timer? _hideSyncedStatusTimer;
  bool _isLoading = true;
  String? _loadError;

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
    _loadRecipes();
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
      unawaited(_loadRecipes());
    }
  }

  Future<void> _loadRecipes() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final recipes = await widget.repo.getAll();
      final mealSlots = await widget.mealPlanRepo.getRange(
        from: _today,
        to: _today.add(const Duration(days: 3)),
      );
      final todaySlots = mealSlots
          .where((slot) => _isSameDay(slot.plannedFor, _today))
          .toList();
      if (!mounted) return;
      setState(() {
        _recipes = recipes;
        _upcomingMealSlots = mealSlots;
        _mealRecipeIds
          ..clear()
          ..addAll(_slotValues(todaySlots));
        _mealExtras
          ..clear()
          ..addAll(_extrasValues(todaySlots));
        _mealRecipeExtraIds
          ..clear()
          ..addAll(_recipeExtraIdsValues(todaySlots));
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

  Recipe? _recipeById(String? id) {
    if (id == null) return null;
    for (final recipe in _recipes) {
      if (recipe.id == id) return recipe;
    }
    return null;
  }

  Recipe? _recipeForSlot(String slotId) {
    if (_mealRecipeIds.containsKey(slotId)) {
      return _recipeById(_mealRecipeIds[slotId]);
    }
    return null;
  }

  bool _isLeftoversSlot(String slotId) {
    return _mealRecipeIds[slotId] == MealChoiceSheet.leftoversValue;
  }

  Future<void> _openRecipe(Recipe? recipe) async {
    if (recipe == null) return;
    await context.push('/details', extra: recipe);
    await _loadRecipes();
  }

  Future<void> _chooseRecipe(String slotId) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => MealChoiceSheet(recipes: _recipes),
    );
    if (selected == null || !mounted) return;

    setState(() => _mealRecipeIds[slotId] = selected);
    try {
      if (selected == MealChoiceSheet.leftoversValue) {
        await widget.mealPlanRepo.setLeftovers(date: _today, meal: slotId);
      } else {
        await widget.mealPlanRepo.setRecipe(
          date: _today,
          meal: slotId,
          recipeId: selected,
        );
      }
    } catch (error) {
      if (!mounted) return;
      if (error is MealPlanQueuedException) {
        _showPlanMessage(error.userMessage);
        return;
      }
      await _loadRecipes();
      _showPlanMessage(_mealPlanErrorMessage(error));
    }
  }

  Future<void> _clearRecipe(String slotId) async {
    setState(() => _mealRecipeIds[slotId] = null);
    try {
      await widget.mealPlanRepo.setEmpty(date: _today, meal: slotId);
    } catch (error) {
      if (!mounted) return;
      if (error is MealPlanQueuedException) {
        _showPlanMessage(error.userMessage);
        return;
      }
      await _loadRecipes();
      _showPlanMessage(_mealPlanErrorMessage(error));
    }
  }

  Future<void> _editExtras(String slotId) async {
    final result = await showModalBottomSheet<MealExtrasResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => MealExtrasSheet(
        initialExtras: _mealExtras[slotId] ?? const [],
        initialRecipeExtraIds: _mealRecipeExtraIds[slotId] ?? const [],
        recipes: _recipes,
      ),
    );
    if (result == null || !mounted) return;

    final previous = _mealExtras[slotId] ?? const <String>[];
    final previousRecipeIds = _mealRecipeExtraIds[slotId] ?? const <String>[];
    setState(() {
      _mealExtras[slotId] = result.extras;
      _mealRecipeExtraIds[slotId] = result.recipeExtraIds;
    });
    try {
      await widget.mealPlanRepo.setExtras(
        date: _today,
        meal: slotId,
        extras: result.extras,
        recipeExtraIds: result.recipeExtraIds,
      );
    } catch (error) {
      if (!mounted) return;
      if (error is MealPlanQueuedException) {
        _showPlanMessage(error.userMessage);
        return;
      }
      setState(() {
        _mealExtras[slotId] = previous;
        _mealRecipeExtraIds[slotId] = previousRecipeIds;
      });
      _showPlanMessage(_mealPlanErrorMessage(error));
    }
  }

  Future<void> _repeatRecipe(
    String slotId,
    String mealTitle,
    Recipe recipe,
  ) async {
    final weekdays = await showModalBottomSheet<Set<int>>(
      context: context,
      showDragHandle: true,
      builder: (context) => _RepeatMealSheet(
        mealTitle: mealTitle,
        recipeTitle: recipe.title,
        startDate: _today,
        endDate: _endOfWeek(_today),
      ),
    );
    if (weekdays == null || weekdays.isEmpty || !mounted) return;

    final dates = _datesUntil(
      _today,
      _endOfWeek(_today),
    ).where((date) => weekdays.contains(date.weekday)).toList();
    if (dates.isEmpty) return;

    var queuedCount = 0;
    for (final date in dates) {
      try {
        await widget.mealPlanRepo.setRecipe(
          date: date,
          meal: slotId,
          recipeId: recipe.id,
        );
      } catch (error) {
        if (!mounted) return;
        if (error is MealPlanQueuedException) {
          queuedCount += 1;
          continue;
        }
        _showPlanMessage(_mealPlanErrorMessage(error));
        await _loadRecipes();
        return;
      }
    }

    if (!mounted) return;
    await _loadRecipes();
    final suffix = queuedCount > 0
        ? ' Wird synchronisiert, sobald die Verbindung wieder da ist.'
        : '';
    _showPlanMessage('${dates.length} Mahlzeiten geplant.$suffix');
  }

  Map<String, String?> _slotValues(List<MealPlanSlot> slots) {
    return {
      for (final slot in slots)
        slot.meal: slot.isLeftovers
            ? MealChoiceSheet.leftoversValue
            : slot.isRecipe
            ? slot.recipeId
            : null,
    };
  }

  Map<String, List<String>> _extrasValues(List<MealPlanSlot> slots) {
    return {for (final slot in slots) slot.meal: slot.extras};
  }

  Map<String, List<String>> _recipeExtraIdsValues(List<MealPlanSlot> slots) {
    return {for (final slot in slots) slot.meal: slot.recipeExtraIds};
  }

  List<String> _extraLabels(String meal) {
    return [
      for (final id in _mealRecipeExtraIds[meal] ?? const <String>[])
        if (_recipeById(id) != null) _recipeById(id)!.title,
      ...(_mealExtras[meal] ?? const <String>[]),
    ];
  }

  List<_PreparationTask> _preparationTasks() {
    final tasks = <_PreparationTask>[];
    final seen = <String>{};

    for (final slot in _upcomingMealSlots) {
      if (slot.isRecipe) {
        final recipe = _recipeById(slot.recipeId);
        if (recipe != null) {
          _addPreparationTasksForRecipe(
            tasks: tasks,
            seen: seen,
            slot: slot,
            recipe: recipe,
          );
        }
      }

      for (final recipeId in slot.recipeExtraIds) {
        final recipe = _recipeById(recipeId);
        if (recipe != null) {
          _addPreparationTasksForRecipe(
            tasks: tasks,
            seen: seen,
            slot: slot,
            recipe: recipe,
            isSide: true,
          );
        }
      }
    }

    tasks.sort((a, b) {
      final dateCompare = a.plannedFor.compareTo(b.plannedFor);
      if (dateCompare != 0) return dateCompare;
      final mealCompare = _mealOrder(a.meal).compareTo(_mealOrder(b.meal));
      if (mealCompare != 0) return mealCompare;
      return a.recipeTitle.compareTo(b.recipeTitle);
    });
    return tasks.take(6).toList();
  }

  void _addPreparationTasksForRecipe({
    required List<_PreparationTask> tasks,
    required Set<String> seen,
    required MealPlanSlot slot,
    required Recipe recipe,
    bool isSide = false,
  }) {
    final candidates = recipe.preparationTasks.isNotEmpty
        ? recipe.preparationTasks
        : [
            ...recipe.instructions,
            if (recipe.notes.trim().isNotEmpty) recipe.notes,
          ];

    for (final candidate in candidates) {
      final instruction = recipe.preparationTasks.isNotEmpty
          ? candidate.trim().replaceAll(RegExp(r'\s+'), ' ')
          : _preparationInstruction(candidate);
      if (instruction == null) continue;
      if (instruction.isEmpty) continue;
      final key =
          '${slot.plannedFor.toIso8601String()}|${slot.meal}|${recipe.id}|$instruction|$isSide';
      if (!seen.add(key)) continue;
      tasks.add(
        _PreparationTask(
          recipeTitle: recipe.title,
          plannedFor: slot.plannedFor,
          meal: slot.meal,
          instruction: instruction,
          durationLabel: _preparationDurationLabel(instruction),
          isSide: isSide,
        ),
      );
    }
  }

  String? _preparationInstruction(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) return null;
    final lower = normalized.toLowerCase();
    final hasPreparationSignal = _preparationSignals.any(lower.contains);
    if (!hasPreparationSignal) return null;
    return normalized;
  }

  String? _preparationDurationLabel(String instruction) {
    final lower = instruction.toLowerCase();
    if (lower.contains('über nacht') ||
        lower.contains('ueber nacht') ||
        lower.contains('overnight')) {
      return 'über Nacht';
    }

    final match = RegExp(
      r'(\d+(?:[,.]\d+)?)\s*(stunden?|std\.?|h|minuten?|min|tage?|tag)\b',
      caseSensitive: false,
    ).firstMatch(instruction);
    if (match == null) return null;

    final amount = match.group(1)!.replaceAll('.', ',');
    final unit = match.group(2)!.toLowerCase();
    if (unit.startsWith('min')) return '$amount Min.';
    if (unit == 'h' || unit.startsWith('std') || unit.startsWith('stund')) {
      return '$amount Std.';
    }
    return amount == '1' ? '1 Tag' : '$amount Tage';
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

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static DateTime _endOfWeek(DateTime date) {
    return _dateOnly(date).add(Duration(days: 7 - date.weekday));
  }

  static Iterable<DateTime> _datesUntil(DateTime start, DateTime end) sync* {
    var cursor = _dateOnly(start);
    final last = _dateOnly(end);
    while (!cursor.isAfter(last)) {
      yield cursor;
      cursor = cursor.add(const Duration(days: 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final breakfast = _recipeForSlot('breakfast');
    final lunch = _recipeForSlot('lunch');
    final dinner = _recipeForSlot('dinner');
    final breakfastIsLeftovers = _isLeftoversSlot('breakfast');
    final lunchIsLeftovers = _isLeftoversSlot('lunch');
    final dinnerIsLeftovers = _isLeftoversSlot('dinner');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Heute'),
        actions: [BackendConnectionIcon(mealPlanRepo: widget.mealPlanRepo)],
      ),
      body: _isLoading
          ? const LoadStateView.loading()
          : _loadError != null
          ? LoadStateView.error(
              title: 'Heute konnte nicht geladen werden',
              message:
                  'Prüfe, ob der CookBuk-Backendserver läuft und dein Gerät im Tailscale ist.',
              onRetry: _loadRecipes,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                MealPlanSyncBanner(status: _syncStatus),
                if (_syncStatus.isVisible) const SizedBox(height: 12),
                _MealSlotCard(
                  title: 'Frühstück',
                  time: '07:30',
                  recipe: breakfast,
                  isLeftovers: breakfastIsLeftovers,
                  extras: _extraLabels('breakfast'),
                  onTap: breakfast == null || breakfastIsLeftovers
                      ? () => _chooseRecipe('breakfast')
                      : () => _openRecipe(breakfast),
                  onChange: () => _chooseRecipe('breakfast'),
                  onClear: () => _clearRecipe('breakfast'),
                  onExtras: () => _editExtras('breakfast'),
                  onRepeat: breakfast == null || breakfastIsLeftovers
                      ? null
                      : () =>
                            _repeatRecipe('breakfast', 'Frühstück', breakfast),
                ),
                const SizedBox(height: 12),
                _MealSlotCard(
                  title: 'Mittagessen',
                  time: '12:30',
                  recipe: lunch,
                  isLeftovers: lunchIsLeftovers,
                  extras: _extraLabels('lunch'),
                  onTap: lunch == null || lunchIsLeftovers
                      ? () => _chooseRecipe('lunch')
                      : () => _openRecipe(lunch),
                  onChange: () => _chooseRecipe('lunch'),
                  onClear: () => _clearRecipe('lunch'),
                  onExtras: () => _editExtras('lunch'),
                  onRepeat: lunch == null || lunchIsLeftovers
                      ? null
                      : () => _repeatRecipe('lunch', 'Mittagessen', lunch),
                ),
                const SizedBox(height: 12),
                _MealSlotCard(
                  title: 'Abendessen',
                  time: '18:30',
                  recipe: dinner,
                  isLeftovers: dinnerIsLeftovers,
                  extras: _extraLabels('dinner'),
                  onTap: dinner == null || dinnerIsLeftovers
                      ? () => _chooseRecipe('dinner')
                      : () => _openRecipe(dinner),
                  onChange: () => _chooseRecipe('dinner'),
                  onClear: () => _clearRecipe('dinner'),
                  onExtras: () => _editExtras('dinner'),
                  onRepeat: dinner == null || dinnerIsLeftovers
                      ? null
                      : () => _repeatRecipe('dinner', 'Abendessen', dinner),
                ),
                const SizedBox(height: 18),
                _PreparationCard(tasks: _preparationTasks(), today: _today),
              ],
            ),
    );
  }
}

const _preparationSignals = [
  'einweich',
  'quell',
  'kühl',
  'kuehl',
  'kalt stell',
  'kaltstellen',
  'ziehen lass',
  'ruhe',
  'ruhen',
  'marinier',
  'auftau',
  'vorkoch',
  'vorbereit',
  'über nacht',
  'ueber nacht',
  'soak',
  'chill',
  'refrigerate',
  'rest',
  'marinate',
  'thaw',
  'overnight',
];

class _PreparationTask {
  const _PreparationTask({
    required this.recipeTitle,
    required this.plannedFor,
    required this.meal,
    required this.instruction,
    this.durationLabel,
    this.isSide = false,
  });

  final String recipeTitle;
  final DateTime plannedFor;
  final String meal;
  final String instruction;
  final String? durationLabel;
  final bool isSide;
}

class _PreparationCard extends StatelessWidget {
  const _PreparationCard({required this.tasks, required this.today});

  final List<_PreparationTask> tasks;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.hourglass_bottom_rounded,
                  size: 20,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Heute vorbereiten',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (tasks.isEmpty)
              Text(
                'Für die nächsten Tage habe ich nichts mit Einweichen, Kühlen, Marinieren oder Ruhen gefunden.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else
              ...tasks.indexed.map((entry) {
                final index = entry.$1;
                final task = entry.$2;
                return Padding(
                  padding: EdgeInsets.only(top: index == 0 ? 0 : 12),
                  child: _PreparationTaskTile(task: task, today: today),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _PreparationTaskTile extends StatelessWidget {
  const _PreparationTaskTile({required this.task, required this.today});

  final _PreparationTask task;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final meta = [
      _relativeDayLabel(task.plannedFor, today),
      _mealLabel(task.meal),
      if (task.isSide) 'Beilage',
    ].join(' · ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.7),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.checklist_rounded,
            size: 18,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      task.recipeTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  if (task.durationLabel != null) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        task.durationLabel!,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                meta,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                task.instruction,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

int _mealOrder(String meal) {
  switch (meal) {
    case 'breakfast':
      return 0;
    case 'lunch':
      return 1;
    case 'dinner':
      return 2;
  }
  return 3;
}

String _mealLabel(String meal) {
  switch (meal) {
    case 'breakfast':
      return 'Frühstück';
    case 'lunch':
      return 'Mittagessen';
    case 'dinner':
      return 'Abendessen';
  }
  return meal;
}

String _relativeDayLabel(DateTime date, DateTime today) {
  final day = DateTime(date.year, date.month, date.day);
  final base = DateTime(today.year, today.month, today.day);
  final difference = day.difference(base).inDays;
  if (difference == 0) return 'Heute';
  if (difference == 1) return 'Morgen';
  return _weekdayName(day.weekday);
}

String _weekdayName(int weekday) {
  const labels = [
    'Montag',
    'Dienstag',
    'Mittwoch',
    'Donnerstag',
    'Freitag',
    'Samstag',
    'Sonntag',
  ];
  return labels[weekday - 1];
}

class _MealSlotCard extends StatelessWidget {
  const _MealSlotCard({
    required this.title,
    required this.time,
    this.recipe,
    this.isLeftovers = false,
    this.extras = const [],
    this.onTap,
    this.onChange,
    this.onClear,
    this.onExtras,
    this.onRepeat,
  });

  final String title;
  final String time;
  final Recipe? recipe;
  final bool isLeftovers;
  final List<String> extras;
  final VoidCallback? onTap;
  final VoidCallback? onChange;
  final VoidCallback? onClear;
  final VoidCallback? onExtras;
  final VoidCallback? onRepeat;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final imagePath = isLeftovers
        ? MealChoiceSheet.leftoversImagePath
        : recipe?.mainImagePath;
    final isPlanned = recipe != null || isLeftovers;

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
                          placeholderSeed: recipe?.id ?? title,
                        )
                      : UnplannedMealImage(title: title),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      time,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
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
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (onRepeat != null)
                          _MealActionChip(
                            icon: Icons.repeat_rounded,
                            label: 'Wiederholen',
                            onTap: onRepeat!,
                          ),
                        if (recipe?.totalTimeMinutes != null)
                          _MealBadge(
                            icon: Icons.schedule_outlined,
                            label: '${recipe!.totalTimeMinutes} min',
                          ),
                        if (recipe == null && !isLeftovers)
                          const _MealBadge(
                            icon: Icons.add_rounded,
                            label: 'Planen',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _ExtrasButton(onPressed: onExtras, hasExtras: extras.isNotEmpty),
            ],
          ),
        ),
      ),
    );

    if (!isPlanned) return card;

    return _RevealableMealCard(
      onChange: onChange,
      onClear: onClear,
      child: card,
    );
  }
}

class _ExtrasButton extends StatelessWidget {
  const _ExtrasButton({required this.onPressed, required this.hasExtras});

  final VoidCallback? onPressed;
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

class _RevealableMealCard extends StatefulWidget {
  const _RevealableMealCard({required this.child, this.onChange, this.onClear});

  final Widget child;
  final VoidCallback? onChange;
  final VoidCallback? onClear;

  @override
  State<_RevealableMealCard> createState() => _RevealableMealCardState();
}

class _RevealableMealCardState extends State<_RevealableMealCard> {
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
      widget.onChange?.call();
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
                  widget.onClear?.call();
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
      width: _RevealableMealCardState._actionWidth,
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

class _RepeatMealSheet extends StatefulWidget {
  const _RepeatMealSheet({
    required this.mealTitle,
    required this.recipeTitle,
    required this.startDate,
    required this.endDate,
  });

  final String mealTitle;
  final String recipeTitle;
  final DateTime startDate;
  final DateTime endDate;

  @override
  State<_RepeatMealSheet> createState() => _RepeatMealSheetState();
}

class _RepeatMealSheetState extends State<_RepeatMealSheet> {
  late final Set<int> _weekdays = {widget.startDate.weekday};

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Wiederholen', style: textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              '${widget.mealTitle}: ${widget.recipeTitle}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var weekday = 1; weekday <= 7; weekday++)
                  FilterChip(
                    label: Text(_weekdayLabel(weekday)),
                    selected: _weekdays.contains(weekday),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _weekdays.add(weekday);
                        } else {
                          _weekdays.remove(weekday);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Von heute bis Sonntag.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _weekdays.isEmpty
                    ? null
                    : () => Navigator.of(context).pop(_weekdays),
                icon: const Icon(Icons.repeat_rounded),
                label: const Text('Eintragen'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _weekdayLabel(int weekday) {
    const labels = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    return labels[weekday - 1];
  }
}

class _MealActionChip extends StatelessWidget {
  const _MealActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ActionChip(
      avatar: Icon(icon, size: 15, color: colorScheme.primary),
      label: Text(label),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      backgroundColor: colorScheme.surfaceContainerHigh,
      side: BorderSide(color: colorScheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _MealBadge extends StatelessWidget {
  const _MealBadge({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colorScheme.primary),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}
