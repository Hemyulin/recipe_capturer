import 'package:cookbuk/data/meal_plan_repository.dart';
import 'package:cookbuk/domain/meal_plan_slot.dart';

class InMemoryMealPlanRepository implements MealPlanRepository {
  final Map<String, MealPlanSlot> _slots = {};

  @override
  Future<List<MealPlanSlot>> getRange({
    required DateTime from,
    required DateTime to,
  }) async {
    final fromKey = _dateKey(from);
    final toKey = _dateKey(to);
    return _slots.values.where((slot) {
      final key = _dateKey(slot.plannedFor);
      return key.compareTo(fromKey) >= 0 && key.compareTo(toKey) <= 0;
    }).toList();
  }

  @override
  Future<void> setRecipe({
    required DateTime date,
    required String meal,
    required String recipeId,
  }) async {
    _slots[_slotKey(date, meal)] = MealPlanSlot(
      plannedFor: _dateOnly(date),
      meal: meal,
      slotType: 'recipe',
      recipeId: recipeId,
      extras: _slots[_slotKey(date, meal)]?.extras ?? const [],
      recipeExtraIds: _slots[_slotKey(date, meal)]?.recipeExtraIds ?? const [],
    );
  }

  @override
  Future<void> setLeftovers({required DateTime date, required String meal}) {
    _slots[_slotKey(date, meal)] = MealPlanSlot(
      plannedFor: _dateOnly(date),
      meal: meal,
      slotType: 'leftovers',
      extras: _slots[_slotKey(date, meal)]?.extras ?? const [],
      recipeExtraIds: _slots[_slotKey(date, meal)]?.recipeExtraIds ?? const [],
    );
    return Future.value();
  }

  @override
  Future<void> setAway({
    required DateTime date,
    required String meal,
    String reason = '',
  }) {
    _slots[_slotKey(date, meal)] = MealPlanSlot(
      plannedFor: _dateOnly(date),
      meal: meal,
      slotType: 'away',
      extras: _normalizeExtras([reason]),
      recipeExtraIds: const [],
    );
    return Future.value();
  }

  @override
  Future<void> setEmpty({required DateTime date, required String meal}) {
    _slots[_slotKey(date, meal)] = MealPlanSlot(
      plannedFor: _dateOnly(date),
      meal: meal,
      slotType: 'empty',
      extras: const [],
      recipeExtraIds: const [],
    );
    return Future.value();
  }

  @override
  Future<void> setExtras({
    required DateTime date,
    required String meal,
    required List<String> extras,
    List<String> recipeExtraIds = const [],
  }) {
    final key = _slotKey(date, meal);
    final existing = _slots[key];
    _slots[key] = MealPlanSlot(
      plannedFor: _dateOnly(date),
      meal: meal,
      slotType: existing?.slotType ?? 'empty',
      recipeId: existing?.recipeId,
      extras: _normalizeExtras(extras),
      recipeExtraIds: _normalizeRecipeExtraIds(
        recipeExtraIds,
        existing?.recipeId,
      ),
    );
    return Future.value();
  }

  @override
  Future<CloseDayResult> closeDay(DateTime date) {
    final dateKey = _dateKey(date);
    final recordedCount = _slots.values
        .where(
          (slot) =>
              _dateKey(slot.plannedFor) == dateKey &&
              slot.isRecipe &&
              slot.recipeId != null,
        )
        .length;

    return Future.value(
      CloseDayResult(
        plannedFor: _dateOnly(date),
        recordedCount: recordedCount,
        skippedCount: 0,
      ),
    );
  }

  @override
  Future<void> syncPendingChanges() async {}

  String _slotKey(DateTime date, String meal) => '${_dateKey(date)}:$meal';

  String _dateKey(DateTime date) {
    return [
      date.year.toString().padLeft(4, '0'),
      date.month.toString().padLeft(2, '0'),
      date.day.toString().padLeft(2, '0'),
    ].join('-');
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  List<String> _normalizeExtras(List<String> values) {
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .take(8)
        .toList();
  }

  List<String> _normalizeRecipeExtraIds(List<String> values, String? mainId) {
    return values
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty && value != mainId)
        .toSet()
        .take(8)
        .toList();
  }
}
