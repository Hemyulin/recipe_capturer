import 'package:cookbuk/domain/meal_plan_slot.dart';

class CloseDayResult {
  const CloseDayResult({
    required this.plannedFor,
    required this.recordedCount,
    required this.skippedCount,
  });

  final DateTime plannedFor;
  final int recordedCount;
  final int skippedCount;

  factory CloseDayResult.fromJson(Map<String, dynamic> json) {
    return CloseDayResult(
      plannedFor: DateTime.parse(json['plannedFor'] as String),
      recordedCount: json['recordedCount'] as int? ?? 0,
      skippedCount: json['skippedCount'] as int? ?? 0,
    );
  }
}

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

  Future<CloseDayResult> closeDay(DateTime date);
}
