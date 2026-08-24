import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cookbuk/data/meal_plan_repository.dart';

class BackendConnectionIcon extends StatefulWidget {
  const BackendConnectionIcon({super.key, required this.mealPlanRepo});

  final MealPlanRepository mealPlanRepo;

  @override
  State<BackendConnectionIcon> createState() => _BackendConnectionIconState();
}

class _BackendConnectionIconState extends State<BackendConnectionIcon> {
  bool? _isConnected;
  StreamSubscription<MealPlanSyncStatus>? _subscription;

  @override
  void initState() {
    super.initState();
    final diagnostics = _diagnostics;
    if (diagnostics == null) return;

    _isConnected = diagnostics.lastSuccessfulConnectionAt != null;
    _subscription = diagnostics.syncStatusChanges.listen((status) {
      if (!mounted) return;
      setState(() {
        _isConnected = switch (status.phase) {
          MealPlanSyncPhase.synced => true,
          MealPlanSyncPhase.queued || MealPlanSyncPhase.blocked => false,
          MealPlanSyncPhase.syncing || MealPlanSyncPhase.idle => _isConnected,
        };
      });
    });
    unawaited(_refresh());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  MealPlanConnectionDiagnostics? get _diagnostics {
    final repo = widget.mealPlanRepo;
    if (repo is MealPlanConnectionDiagnostics) {
      return repo as MealPlanConnectionDiagnostics;
    }
    return null;
  }

  Future<void> _refresh() async {
    final diagnostics = _diagnostics;
    if (diagnostics == null) return;
    final result = await diagnostics.testConnection();
    if (!mounted) return;
    setState(() => _isConnected = result.isConnected);
  }

  @override
  Widget build(BuildContext context) {
    final diagnostics = _diagnostics;
    if (diagnostics == null) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final knownDisconnected = _isConnected == false;
    if (!knownDisconnected) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 6),
      child: Tooltip(
        message: 'Pi nicht verbunden',
        child: TextButton.icon(
          onPressed: () => context.go('/status'),
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            minimumSize: const Size(0, 34),
            backgroundColor: colorScheme.secondaryContainer,
            foregroundColor: colorScheme.onSecondaryContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          icon: const Icon(Icons.warning_amber_rounded, size: 17),
          label: const Text('Offline'),
        ),
      ),
    );
  }
}
