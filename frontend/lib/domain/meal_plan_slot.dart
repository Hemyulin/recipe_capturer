class MealPlanSlot {
  const MealPlanSlot({
    required this.plannedFor,
    required this.meal,
    required this.slotType,
    this.recipeId,
  });

  final DateTime plannedFor;
  final String meal;
  final String slotType;
  final String? recipeId;

  bool get isRecipe => slotType == 'recipe';
  bool get isLeftovers => slotType == 'leftovers';
  bool get isEmpty => slotType == 'empty';

  factory MealPlanSlot.fromJson(Map<String, dynamic> json) {
    return MealPlanSlot(
      plannedFor: DateTime.parse(json['plannedFor'] as String),
      meal: json['meal'] as String,
      slotType: json['slotType'] as String,
      recipeId: json['recipeId'] as String?,
    );
  }
}
