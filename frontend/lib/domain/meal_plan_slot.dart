class MealPlanSlot {
  const MealPlanSlot({
    required this.plannedFor,
    required this.meal,
    required this.slotType,
    this.recipeId,
    this.extras = const [],
    this.recipeExtraIds = const [],
  });

  final DateTime plannedFor;
  final String meal;
  final String slotType;
  final String? recipeId;
  final List<String> extras;
  final List<String> recipeExtraIds;

  bool get isRecipe => slotType == 'recipe';
  bool get isLeftovers => slotType == 'leftovers';
  bool get isAway => slotType == 'away';
  bool get isEmpty => slotType == 'empty';
  String get awayReason => isAway && extras.isNotEmpty ? extras.first : '';

  factory MealPlanSlot.fromJson(Map<String, dynamic> json) {
    return MealPlanSlot(
      plannedFor: DateTime.parse(json['plannedFor'] as String),
      meal: json['meal'] as String,
      slotType: json['slotType'] as String,
      recipeId: json['recipeId'] as String?,
      extras: (json['extras'] as List<dynamic>? ?? [])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(),
      recipeExtraIds: (json['recipeExtraIds'] as List<dynamic>? ?? [])
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList(),
    );
  }
}
