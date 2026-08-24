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
        to: _today,
      );
      if (!mounted) return;
      setState(() {
        _recipes = recipes;
        _mealRecipeIds
          ..clear()
          ..addAll(_slotValues(mealSlots));
        _mealExtras
          ..clear()
          ..addAll(_extrasValues(mealSlots));
        _mealRecipeExtraIds
          ..clear()
          ..addAll(_recipeExtraIdsValues(mealSlots));
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
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
              children: [
                MealPlanSyncBanner(status: _syncStatus),
                if (_syncStatus.isVisible) const SizedBox(height: 12),
                _MealSlotCard(
                  title: 'Frühstück',
                  time: '07:30',
                  recipe: breakfast,
                  isLeftovers: breakfastIsLeftovers,
                  extras: _extraLabels('breakfast'),
                  isRecurring: breakfast != null && !breakfastIsLeftovers,
                  onTap: breakfast == null || breakfastIsLeftovers
                      ? () => _chooseRecipe('breakfast')
                      : () => _openRecipe(breakfast),
                  onChange: () => _chooseRecipe('breakfast'),
                  onClear: () => _clearRecipe('breakfast'),
                  onExtras: () => _editExtras('breakfast'),
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
                ),
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Heute vorbereiten',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Noch keine Vorbereitung geplant.',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _MealSlotCard extends StatelessWidget {
  const _MealSlotCard({
    required this.title,
    required this.time,
    this.recipe,
    this.isLeftovers = false,
    this.extras = const [],
    this.isRecurring = false,
    this.onTap,
    this.onChange,
    this.onClear,
    this.onExtras,
  });

  final String title;
  final String time;
  final Recipe? recipe;
  final bool isLeftovers;
  final List<String> extras;
  final bool isRecurring;
  final VoidCallback? onTap;
  final VoidCallback? onChange;
  final VoidCallback? onClear;
  final VoidCallback? onExtras;

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
                        if (isRecurring)
                          const _MealBadge(
                            icon: Icons.lock_outline,
                            label: 'wiederkehrend',
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
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          minimumSize: const Size(0, 34),
          foregroundColor: hasExtras
              ? colorScheme.onSecondaryContainer
              : colorScheme.onSurfaceVariant,
          backgroundColor: hasExtras
              ? colorScheme.secondaryContainer
              : colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        icon: const Icon(Icons.restaurant_menu_rounded, size: 16),
        label: const Text('Beilagen'),
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
