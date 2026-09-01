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

class MealPlanSaveException implements Exception {
  const MealPlanSaveException(this.userMessage);

  final String userMessage;

  @override
  String toString() => userMessage;
}

class MealPlanQueuedException extends MealPlanSaveException {
  const MealPlanQueuedException(super.userMessage);
}

enum MealPlanSyncPhase { idle, queued, syncing, synced, blocked }

class MealPlanSyncStatus {
  const MealPlanSyncStatus({
    required this.phase,
    this.pendingCount = 0,
    this.message,
  });

  final MealPlanSyncPhase phase;
  final int pendingCount;
  final String? message;

  bool get isVisible => phase != MealPlanSyncPhase.idle;

  static const idle = MealPlanSyncStatus(phase: MealPlanSyncPhase.idle);
}

abstract interface class MealPlanSyncNotifier {
  MealPlanSyncStatus get syncStatus;

  Stream<MealPlanSyncStatus> get syncStatusChanges;
}

class BackendConnectionTestResult {
  const BackendConnectionTestResult({
    required this.isConnected,
    required this.checkedAt,
    required this.message,
    this.activeBaseUrl,
  });

  final bool isConnected;
  final DateTime checkedAt;
  final String message;
  final String? activeBaseUrl;
}

abstract interface class MealPlanConnectionDiagnostics
    implements MealPlanSyncNotifier {
  List<String> get configuredBaseUrls;

  String get activeBaseUrl;

  int get pendingWriteCount;

  DateTime? get lastSuccessfulConnectionAt;

  Future<BackendConnectionTestResult> testConnection();
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

  Future<void> setAway({
    required DateTime date,
    required String meal,
    String reason = '',
  });

  Future<void> setEmpty({required DateTime date, required String meal});

  Future<void> setExtras({
    required DateTime date,
    required String meal,
    required List<String> extras,
    List<String> recipeExtraIds = const [],
  });

  Future<CloseDayResult> closeDay(DateTime date);

  Future<void> syncPendingChanges() async {}
}
