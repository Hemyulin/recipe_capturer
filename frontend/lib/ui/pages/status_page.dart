import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cookbuk/data/meal_plan_repository.dart';

class StatusPage extends StatefulWidget {
  const StatusPage({super.key, required this.mealPlanRepo});

  final MealPlanRepository mealPlanRepo;

  @override
  State<StatusPage> createState() => _StatusPageState();
}

class _StatusPageState extends State<StatusPage> {
  MealPlanConnectionDiagnostics? _diagnostics;
  MealPlanSyncStatus _syncStatus = MealPlanSyncStatus.idle;
  BackendConnectionTestResult? _lastTestResult;
  StreamSubscription<MealPlanSyncStatus>? _syncStatusSubscription;
  bool _isTesting = false;

  @override
  void initState() {
    super.initState();
    final repo = widget.mealPlanRepo;
    if (repo is MealPlanConnectionDiagnostics) {
      final diagnostics = repo as MealPlanConnectionDiagnostics;
      _diagnostics = diagnostics;
      _syncStatus = diagnostics.syncStatus;
      _syncStatusSubscription = diagnostics.syncStatusChanges.listen((status) {
        if (mounted) setState(() => _syncStatus = status);
      });
      unawaited(widget.mealPlanRepo.syncPendingChanges().catchError((_) {}));
    }
  }

  @override
  void dispose() {
    _syncStatusSubscription?.cancel();
    super.dispose();
  }

  Future<void> _testConnection() async {
    final diagnostics = _diagnostics;
    if (diagnostics == null || _isTesting) return;

    setState(() => _isTesting = true);
    final result = await diagnostics.testConnection();
    if (!mounted) return;
    setState(() {
      _lastTestResult = result;
      _syncStatus = diagnostics.syncStatus;
      _isTesting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final diagnostics = _diagnostics;

    return Scaffold(
      appBar: AppBar(title: const Text('Status')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          if (diagnostics == null)
            const _StatusPanel(
              icon: Icons.info_outline_rounded,
              title: 'Lokaler Modus',
              message: 'Diese App-Variante liefert keine Backend-Diagnose.',
            )
          else ...[
            _ConnectionSummary(
              status: _syncStatus,
              result: _lastTestResult,
              onTest: _testConnection,
              isTesting: _isTesting,
            ),
            const SizedBox(height: 12),
            _StatusCard(
              title: 'Backend',
              rows: [
                _StatusRow(label: 'Aktiv', value: diagnostics.activeBaseUrl),
                _StatusRow(
                  label: 'Letzter Erfolg',
                  value: _formatDateTime(
                    diagnostics.lastSuccessfulConnectionAt,
                  ),
                ),
                _StatusRow(
                  label: 'Offene Änderungen',
                  value: diagnostics.pendingWriteCount.toString(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _StatusCard(
              title: 'Konfigurierte Adressen',
              rows: [
                for (final url in diagnostics.configuredBaseUrls)
                  _StatusRow(label: 'URL', value: url),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDateTime(DateTime? value) {
    if (value == null) return 'Noch nie';
    final local = value.toLocal();
    final date =
        '${local.day.toString().padLeft(2, '0')}.${local.month.toString().padLeft(2, '0')}.${local.year}';
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }
}

class _ConnectionSummary extends StatelessWidget {
  const _ConnectionSummary({
    required this.status,
    required this.result,
    required this.onTest,
    required this.isTesting,
  });

  final MealPlanSyncStatus status;
  final BackendConnectionTestResult? result;
  final VoidCallback onTest;
  final bool isTesting;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isConnected = result?.isConnected == true;
    final title = result == null
        ? _statusTitle(status.phase)
        : isConnected
        ? 'Verbunden'
        : 'Nicht verbunden';
    final message = result?.message ?? status.message ?? _statusMessage(status);
    final icon = isTesting
        ? Icons.sync_rounded
        : isConnected
        ? Icons.cloud_done_outlined
        : _statusIcon(status.phase);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: isTesting ? null : onTest,
              icon: Icon(
                isTesting ? Icons.sync_rounded : Icons.network_check_rounded,
              ),
              label: Text(isTesting ? 'Teste...' : 'Verbindung testen'),
            ),
          ],
        ),
      ),
    );
  }

  String _statusTitle(MealPlanSyncPhase phase) {
    return switch (phase) {
      MealPlanSyncPhase.queued => 'Wartet auf Verbindung',
      MealPlanSyncPhase.syncing => 'Synchronisiert',
      MealPlanSyncPhase.synced => 'Synchronisiert',
      MealPlanSyncPhase.blocked => 'Blockiert',
      MealPlanSyncPhase.idle => 'Bereit',
    };
  }

  String _statusMessage(MealPlanSyncStatus status) {
    return switch (status.phase) {
      MealPlanSyncPhase.queued =>
        'Änderungen werden gespeichert, sobald der Pi erreichbar ist.',
      MealPlanSyncPhase.syncing => 'Offene Änderungen werden zum Pi geschickt.',
      MealPlanSyncPhase.synced => 'Alle Änderungen wurden gespeichert.',
      MealPlanSyncPhase.blocked => 'Der Pi hat eine Änderung abgelehnt.',
      MealPlanSyncPhase.idle => 'Keine offenen Änderungen.',
    };
  }

  IconData _statusIcon(MealPlanSyncPhase phase) {
    return switch (phase) {
      MealPlanSyncPhase.queued => Icons.cloud_off_outlined,
      MealPlanSyncPhase.syncing => Icons.sync_rounded,
      MealPlanSyncPhase.synced => Icons.cloud_done_outlined,
      MealPlanSyncPhase.blocked => Icons.error_outline_rounded,
      MealPlanSyncPhase.idle => Icons.check_circle_outline_rounded,
    };
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.title, required this.rows});

  final String title;
  final List<_StatusRow> rows;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            for (final row in rows) row,
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
