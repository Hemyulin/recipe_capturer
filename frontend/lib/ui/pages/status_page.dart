import 'dart:async';
import 'dart:io';

import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cookbuk/config/theme_controller.dart';
import 'package:cookbuk/config/theme_presets.dart';
import 'package:cookbuk/data/meal_plan_repository.dart';
import 'package:cookbuk/data/recipe_repository.dart';
import 'package:cookbuk/ui/widgets/backend_connection_icon.dart';
import 'package:go_router/go_router.dart';

class StatusPage extends StatefulWidget {
  const StatusPage({super.key, required this.mealPlanRepo, this.recipeRepo});

  final MealPlanRepository mealPlanRepo;
  final RecipeRepository? recipeRepo;

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

  Future<void> _openTailscale() async {
    if (Platform.isAndroid && await _openTailscaleAndroidApp()) return;

    final opened = await _tryOpenExternalUrls([
      'market://details?id=com.tailscale.ipn',
      'https://play.google.com/store/apps/details?id=com.tailscale.ipn',
      'https://login.tailscale.com/admin/machines',
    ]);
    if (opened || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tailscale konnte nicht geöffnet werden.')),
    );
  }

  Future<bool> _openTailscaleAndroidApp() async {
    try {
      final isInstalled = await LaunchApp.isAppInstalled(
        androidPackageName: 'com.tailscale.ipn',
      );
      if (isInstalled != true) return false;

      final result = await LaunchApp.openApp(
        androidPackageName: 'com.tailscale.ipn',
        openStore: false,
      );
      return result == 1;
    } on Object {
      return false;
    }
  }

  Future<bool> _tryOpenExternalUrls(List<String> values) async {
    for (final value in values) {
      try {
        final opened = await launchUrl(
          Uri.parse(value),
          mode: LaunchMode.externalApplication,
        );
        if (opened) return true;
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final diagnostics = _diagnostics;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
        actions: [BackendConnectionIcon(mealPlanRepo: widget.mealPlanRepo)],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          Text('Verbindung', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
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
              onOpenTailscale: _openTailscale,
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
          const SizedBox(height: 20),
          Text('Kochen', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          _SettingsActionCard(
            icon: Icons.query_stats_outlined,
            title: 'Statistiken',
            message: 'Lieblingsessen, Kochhistorie und offene Reviews.',
            onTap: widget.recipeRepo == null
                ? null
                : () => context.push('/statistics'),
          ),
          const SizedBox(height: 20),
          Text('Design', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 10),
          const _ThemeSettingsCard(),
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
    required this.onOpenTailscale,
    required this.isTesting,
  });

  final MealPlanSyncStatus status;
  final BackendConnectionTestResult? result;
  final VoidCallback onTest;
  final VoidCallback onOpenTailscale;
  final bool isTesting;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isConnected = result?.isConnected == true;
    final isDisconnected = result?.isConnected == false;
    final warningColor = colorScheme.secondary;
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
        : isDisconnected
        ? Icons.cancel_outlined
        : _statusIcon(status.phase);
    final iconColor = isDisconnected ? warningColor : colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatusIcon(
                  icon: icon,
                  color: iconColor,
                  isSpinning: isTesting,
                ),
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
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: isTesting ? null : onTest,
                  style: isDisconnected
                      ? FilledButton.styleFrom(
                          backgroundColor: warningColor,
                          foregroundColor: colorScheme.onSecondary,
                        )
                      : null,
                  icon: Icon(
                    isTesting
                        ? Icons.sync_rounded
                        : Icons.network_check_rounded,
                  ),
                  label: Text(isTesting ? 'Teste...' : 'Verbindung testen'),
                ),
                OutlinedButton.icon(
                  onPressed: onOpenTailscale,
                  icon: const Icon(Icons.vpn_key_outlined),
                  label: const Text('Tailscale öffnen'),
                ),
              ],
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

class _StatusIcon extends StatefulWidget {
  const _StatusIcon({
    required this.icon,
    required this.color,
    required this.isSpinning,
  });

  final IconData icon;
  final Color color;
  final bool isSpinning;

  @override
  State<_StatusIcon> createState() => _StatusIconState();
}

class _StatusIconState extends State<_StatusIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isSpinning) _controller.repeat();
  }

  @override
  void didUpdateWidget(_StatusIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSpinning && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isSpinning && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(widget.icon, color: widget.color);
    if (!widget.isSpinning) return icon;

    return RotationTransition(turns: _controller, child: icon);
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

class _ThemeSettingsCard extends StatelessWidget {
  const _ThemeSettingsCard();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final preset in CookbukThemes.presets)
                  _ThemeChoice(
                    preset: preset,
                    isSelected: preset.id == themeController.themeId,
                    onTap: () => themeController.setTheme(preset.id),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice({
    required this.preset,
    required this.isSelected,
    required this.onTap,
  });

  final CookbukThemePreset preset;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minWidth: 132),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant,
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ThemeSwatches(colors: preset.swatches),
            const SizedBox(width: 10),
            Text(
              preset.label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeSwatches extends StatelessWidget {
  const _ThemeSwatches({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 38,
      height: 18,
      child: Stack(
        children: [
          for (var index = 0; index < colors.length; index++)
            Positioned(
              left: index * 10,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: colors[index],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SettingsActionCard extends StatelessWidget {
  const _SettingsActionCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: colorScheme.primary),
        title: Text(title, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(message),
        trailing: const Icon(Icons.chevron_right_rounded),
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
