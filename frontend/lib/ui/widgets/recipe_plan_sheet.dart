import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cookbuk/data/meal_plan_repository.dart';
import 'package:cookbuk/domain/meal_plan_slot.dart';
import 'package:cookbuk/domain/recipe.dart';

class RecipePlanSelection {
  const RecipePlanSelection({required this.date, required this.meal});

  final DateTime date;
  final String meal;
}

Future<void> showRecipePlanSheet({
  required BuildContext context,
  required Recipe recipe,
  required MealPlanRepository mealPlanRepo,
}) async {
  final selection = await showModalBottomSheet<RecipePlanSelection>(
    context: context,
    showDragHandle: true,
    builder: (context) => _RecipePlanSheet(recipe: recipe),
  );
  if (selection == null || !context.mounted) return;

  final previousSlot = await _loadExistingSlot(mealPlanRepo, selection);
  try {
    await mealPlanRepo.setRecipe(
      date: selection.date,
      meal: selection.meal,
      recipeId: recipe.id,
    );
    if (!context.mounted) return;
    _showPlanConfirmation(
      context: context,
      recipe: recipe,
      selection: selection,
      mealPlanRepo: mealPlanRepo,
      previousSlot: previousSlot,
    );
  } catch (error) {
    if (!context.mounted) return;
    if (error is MealPlanQueuedException) {
      _showPlanConfirmation(
        context: context,
        recipe: recipe,
        selection: selection,
        mealPlanRepo: mealPlanRepo,
        previousSlot: previousSlot,
        queuedMessage: error.userMessage,
      );
      return;
    }
    final message = error is MealPlanSaveException
        ? error.userMessage
        : 'Rezept konnte nicht geplant werden.';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

Future<MealPlanSlot?> _loadExistingSlot(
  MealPlanRepository mealPlanRepo,
  RecipePlanSelection selection,
) async {
  try {
    final slots = await mealPlanRepo.getRange(
      from: selection.date,
      to: selection.date,
    );
    for (final slot in slots) {
      if (slot.meal == selection.meal) return slot;
    }
  } catch (_) {
    return null;
  }
  return null;
}

void _showPlanConfirmation({
  required BuildContext context,
  required Recipe recipe,
  required RecipePlanSelection selection,
  required MealPlanRepository mealPlanRepo,
  required MealPlanSlot? previousSlot,
  String? queuedMessage,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.clearSnackBars();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            queuedMessage ??
                '${recipe.title} ist ${_relativeDateLabel(selection.date).toLowerCase()} zum ${_mealLabel(selection.meal)} geplant.',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: [
              TextButton(
                onPressed: () {
                  messenger.hideCurrentSnackBar();
                  context.go('/week');
                },
                child: const Text('Plan ansehen'),
              ),
              TextButton(
                onPressed: () {
                  messenger.hideCurrentSnackBar();
                  unawaited(
                    _restoreSlot(mealPlanRepo, selection, previousSlot),
                  );
                },
                child: const Text('Rückgängig'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Future<void> _restoreSlot(
  MealPlanRepository mealPlanRepo,
  RecipePlanSelection selection,
  MealPlanSlot? previousSlot,
) async {
  final slot = previousSlot;
  try {
    if (slot == null || slot.isEmpty) {
      await mealPlanRepo.setEmpty(date: selection.date, meal: selection.meal);
      return;
    }
    if (slot.isLeftovers) {
      await mealPlanRepo.setLeftovers(date: selection.date, meal: slot.meal);
    } else if (slot.isRecipe && slot.recipeId != null) {
      await mealPlanRepo.setRecipe(
        date: selection.date,
        meal: slot.meal,
        recipeId: slot.recipeId!,
      );
    }
    if (slot.extras.isNotEmpty || slot.recipeExtraIds.isNotEmpty) {
      await mealPlanRepo.setExtras(
        date: selection.date,
        meal: slot.meal,
        extras: slot.extras,
        recipeExtraIds: slot.recipeExtraIds,
      );
    }
  } catch (_) {
    // The normal offline queue will retry; the snackbar should stay lightweight.
  }
}

class _RecipePlanSheet extends StatefulWidget {
  const _RecipePlanSheet({required this.recipe});

  final Recipe recipe;

  @override
  State<_RecipePlanSheet> createState() => _RecipePlanSheetState();
}

class _RecipePlanSheetState extends State<_RecipePlanSheet> {
  late DateTime _selectedDate = _dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dates = _planningDateChoices();

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Zum Wochenplan',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              widget.recipe.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final date in dates)
                  ChoiceChip(
                    label: Text(_dateChoiceLabel(date)),
                    selected: _isSameDay(date, _selectedDate),
                    onSelected: (_) => setState(() => _selectedDate = date),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _MealButton(
                    icon: Icons.wb_sunny_outlined,
                    label: 'Frühstück',
                    onTap: () => _selectMeal('breakfast'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MealButton(
                    icon: Icons.wb_twilight_outlined,
                    label: 'Mittag',
                    onTap: () => _selectMeal('lunch'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MealButton(
                    icon: Icons.nights_stay_outlined,
                    label: 'Abend',
                    onTap: () => _selectMeal('dinner'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _selectMeal(String meal) {
    Navigator.of(
      context,
    ).pop(RecipePlanSelection(date: _selectedDate, meal: meal));
  }
}

class _MealButton extends StatelessWidget {
  const _MealButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon),
          const SizedBox(height: 5),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

List<DateTime> _planningDateChoices() {
  final today = _dateOnly(DateTime.now());
  final tomorrow = today.add(const Duration(days: 1));
  final weekStart = today.subtract(Duration(days: today.weekday - 1));
  final dates = <DateTime>[today, tomorrow];
  for (var i = 0; i < 7; i++) {
    final date = weekStart.add(Duration(days: i));
    if (!dates.any((existing) => _isSameDay(existing, date))) {
      dates.add(date);
    }
  }
  return dates;
}

String _dateChoiceLabel(DateTime date) {
  final today = _dateOnly(DateTime.now());
  if (_isSameDay(date, today)) return 'Heute';
  if (_isSameDay(date, today.add(const Duration(days: 1)))) return 'Morgen';
  final weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
  return '${weekdays[date.weekday - 1]} ${date.day.toString().padLeft(2, '0')}.';
}

String _relativeDateLabel(DateTime date) {
  final today = _dateOnly(DateTime.now());
  if (_isSameDay(date, today)) return 'Heute';
  if (_isSameDay(date, today.add(const Duration(days: 1)))) return 'Morgen';
  return _dateChoiceLabel(date);
}

String _mealLabel(String meal) {
  return switch (meal) {
    'breakfast' => 'Frühstück',
    'lunch' => 'Mittagessen',
    'dinner' => 'Abendessen',
    _ => meal,
  };
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
