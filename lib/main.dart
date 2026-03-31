import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:recipe_capturer/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const MethodChannel _shareMethodChannel = MethodChannel(
    'recipe_capturer/share_intent_method',
  );
  static const EventChannel _shareEventChannel = EventChannel(
    'recipe_capturer/share_intent_events',
  );

  StreamSubscription<dynamic>? _shareSubscription;
  String? _lastShareSignature;
  DateTime? _lastShareHandledAt;

  @override
  void initState() {
    super.initState();
    _consumeInitialSharePayload();
    _listenForSharedImages();
  }

  @override
  void dispose() {
    _shareSubscription?.cancel();
    super.dispose();
  }

  Future<void> _consumeInitialSharePayload() async {
    try {
      final dynamic raw = await _shareMethodChannel.invokeMethod(
        'consumeInitialSharePayload',
      );
      final payload = _normalizeSharePayload(raw);
      _openFlowFromSharedPayload(payload);
    } catch (_) {
      // Ignore platform channel failures; app should still boot normally.
    }
  }

  void _listenForSharedImages() {
    _shareSubscription = _shareEventChannel.receiveBroadcastStream().listen((
      event,
    ) {
      final payload = _normalizeSharePayload(event);
      _openFlowFromSharedPayload(payload);
    });
  }

  _SharePayload _normalizeSharePayload(dynamic value) {
    if (value is List) {
      final imagePaths = value
          .whereType<String>()
          .where((p) => p.isNotEmpty)
          .toList();
      return _SharePayload(imagePaths: imagePaths);
    }

    if (value is Map) {
      final rawPaths = value['imagePaths'];
      final imagePaths = rawPaths is List
          ? rawPaths.whereType<String>().where((p) => p.isNotEmpty).toList()
          : const <String>[];
      final rawText = value['sharedText'];
      final sharedText = rawText is String ? rawText.trim() : '';

      return _SharePayload(imagePaths: imagePaths, sharedText: sharedText);
    }

    return const _SharePayload();
  }

  void _openFlowFromSharedPayload(_SharePayload payload) {
    final hasImages = payload.imagePaths.isNotEmpty;
    final hasText = payload.sharedText.isNotEmpty;

    if (!hasImages && !hasText) return;

    final signature = '${payload.imagePaths.join('|')}::${payload.sharedText}';
    final now = DateTime.now();
    if (_lastShareSignature == signature &&
        _lastShareHandledAt != null &&
        now.difference(_lastShareHandledAt!).inSeconds < 3) {
      return;
    }
    _lastShareSignature = signature;
    _lastShareHandledAt = now;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      router.push(
        '/import',
        extra: {
          'imagePaths': payload.imagePaths,
          'sharedText': payload.sharedText,
          'pickImagesFirst': !hasImages,
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFFB46D54),
          brightness: Brightness.light,
        ).copyWith(
          secondary: const Color(0xFFD2A997),
          tertiary: const Color(0xFFECCFA9),
          surface: const Color(0xFFFBF7F4),
          surfaceContainerHighest: const Color(0xFFF1E4DC),
        );

    final base = ThemeData(useMaterial3: true, colorScheme: colorScheme);

    final textTheme = base.textTheme.copyWith(
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.35),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.35),
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        textTheme: textTheme,
        scaffoldBackgroundColor: colorScheme.surface,
        appBarTheme: AppBarTheme(
          backgroundColor: colorScheme.surface,
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: textTheme.headlineSmall?.copyWith(
            color: colorScheme.onSurface,
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: colorScheme.secondaryContainer,
          selectedColor: colorScheme.primaryContainer,
          disabledColor: colorScheme.surfaceContainerHighest,
          labelStyle: TextStyle(color: colorScheme.onSecondaryContainer),
          secondaryLabelStyle: TextStyle(color: colorScheme.onPrimaryContainer),
          checkmarkColor: colorScheme.onPrimaryContainer,
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        cardTheme: CardThemeData(
          color: colorScheme.surface,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: colorScheme.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: colorScheme.outlineVariant),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: colorScheme.primary, width: 1.8),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            side: BorderSide(color: colorScheme.outlineVariant),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          extendedTextStyle: TextStyle(
            color: colorScheme.onPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        dividerTheme: DividerThemeData(
          color: colorScheme.outlineVariant.withValues(alpha: 0.55),
        ),
      ),
      routerConfig: router,
    );
  }
}

class _SharePayload {
  const _SharePayload({this.imagePaths = const [], this.sharedText = ''});

  final List<String> imagePaths;
  final String sharedText;
}
