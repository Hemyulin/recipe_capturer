import 'package:flutter/material.dart';
import 'package:cookbuk/data/meal_plan_repository.dart';

class MealPlanSyncBanner extends StatelessWidget {
  const MealPlanSyncBanner({super.key, required this.status});

  final MealPlanSyncStatus status;

  @override
  Widget build(BuildContext context) {
    if (!status.isVisible) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final (
      icon,
      color,
      foregroundColor,
      fallbackMessage,
    ) = switch (status.phase) {
      MealPlanSyncPhase.queued => (
        Icons.cloud_off_outlined,
        colorScheme.tertiaryContainer,
        colorScheme.onTertiaryContainer,
        'Änderung wartet auf Verbindung zum Pi.',
      ),
      MealPlanSyncPhase.syncing => (
        Icons.sync_rounded,
        colorScheme.primaryContainer,
        colorScheme.onPrimaryContainer,
        'Synchronisiere mit dem Pi...',
      ),
      MealPlanSyncPhase.synced => (
        Icons.cloud_done_outlined,
        colorScheme.primaryContainer,
        colorScheme.onPrimaryContainer,
        'Mit dem Pi synchronisiert.',
      ),
      MealPlanSyncPhase.blocked => (
        Icons.error_outline_rounded,
        colorScheme.errorContainer,
        colorScheme.onErrorContainer,
        'Synchronisierung blockiert.',
      ),
      MealPlanSyncPhase.idle => (
        Icons.cloud_done_outlined,
        Colors.transparent,
        colorScheme.onSurface,
        '',
      ),
    };

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Container(
        key: ValueKey('${status.phase}:${status.pendingCount}'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: foregroundColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                status.message ?? fallbackMessage,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: foregroundColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
