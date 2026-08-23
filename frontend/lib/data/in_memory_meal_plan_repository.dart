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
    );
  }

  @override
  Future<void> setLeftovers({required DateTime date, required String meal}) {
    _slots[_slotKey(date, meal)] = MealPlanSlot(
      plannedFor: _dateOnly(date),
      meal: meal,
      slotType: 'leftovers',
    );
    return Future.value();
  }

  @override
  Future<void> setEmpty({required DateTime date, required String meal}) {
    _slots[_slotKey(date, meal)] = MealPlanSlot(
      plannedFor: _dateOnly(date),
      meal: meal,
      slotType: 'empty',
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
}
