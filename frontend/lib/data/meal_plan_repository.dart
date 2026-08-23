import 'package:cookbuk/domain/meal_plan_slot.dart';

abstract class MealPlanRepository {
  Future<List<MealPlanSlot>> getRange({
    required DateTime from,
    required DateTime to,
  });

  Future<void> setRecipe({
    required DateTime date,
    required String meal,
    required String recipeId,
  });

  Future<void> setLeftovers({required DateTime date, required String meal});

  Future<void> setEmpty({required DateTime date, required String meal});
}
