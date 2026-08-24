import 'package:flutter/material.dart';

class CookbukThemePreset {
  const CookbukThemePreset({
    required this.id,
    required this.label,
    required this.seedColor,
    required this.primary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiary,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.surface,
    required this.surfaceLow,
    required this.surfaceHigh,
    required this.surfaceHighest,
    required this.outline,
    required this.outlineVariant,
    required this.gradientEnd,
  });

  final String id;
  final String label;
  final Color seedColor;
  final Color primary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color secondary;
  final Color secondaryContainer;
  final Color onSecondaryContainer;
  final Color tertiary;
  final Color tertiaryContainer;
  final Color onTertiaryContainer;
  final Color surface;
  final Color surfaceLow;
  final Color surfaceHigh;
  final Color surfaceHighest;
  final Color outline;
  final Color outlineVariant;
  final Color gradientEnd;

  List<Color> get swatches => [primary, secondary, tertiary];

  ThemeData buildTheme() {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
        ).copyWith(
          primary: primary,
          onPrimary: Colors.white,
          onPrimaryContainer: onPrimaryContainer,
          primaryContainer: primaryContainer,
          secondary: secondary,
          onSecondary: Colors.white,
          secondaryContainer: secondaryContainer,
          onSecondaryContainer: onSecondaryContainer,
          tertiary: tertiary,
          onTertiary: Colors.white,
          tertiaryContainer: tertiaryContainer,
          onTertiaryContainer: onTertiaryContainer,
          surface: surface,
          onSurface: const Color(0xFF21211D),
          onSurfaceVariant: const Color(0xFF6B6960),
          surfaceContainerLowest: Colors.white,
          surfaceContainerLow: surfaceLow,
          surfaceContainer: surfaceLow,
          surfaceContainerHigh: surfaceHigh,
          surfaceContainerHighest: surfaceHighest,
          outline: outline,
          outlineVariant: outlineVariant,
        );

    final base = ThemeData(useMaterial3: true, colorScheme: colorScheme);
    final textTheme = base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: 0,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      titleSmall: base.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.35),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.35),
      bodySmall: base.textTheme.bodySmall?.copyWith(height: 1.3),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,
      canvasColor: colorScheme.surface,
      splashFactory: NoSplash.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colorScheme.onSurface,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.onSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.surface,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        selectedColor: colorScheme.primaryContainer,
        disabledColor: colorScheme.surfaceContainerHighest,
        labelStyle: TextStyle(color: colorScheme.onSurface),
        secondaryLabelStyle: TextStyle(color: colorScheme.onPrimaryContainer),
        checkmarkColor: colorScheme.onPrimaryContainer,
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLow,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          textStyle: textTheme.titleSmall,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          backgroundColor: colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: BorderSide(color: colorScheme.outlineVariant),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
          textStyle: textTheme.titleSmall,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: colorScheme.onSurface,
          backgroundColor: colorScheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.secondary,
        foregroundColor: colorScheme.onSecondary,
        extendedTextStyle: textTheme.titleSmall?.copyWith(
          color: colorScheme.onSecondary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant.withValues(alpha: 0.75),
      ),
    );
  }
}

class CookbukThemes {
  static const defaultId = 'peach';

  static const presets = [
    CookbukThemePreset(
      id: defaultId,
      label: 'Pfirsich',
      seedColor: Color(0xFF5E8E3E),
      primary: Color(0xFF557A36),
      primaryContainer: Color(0xFFE2ECCC),
      onPrimaryContainer: Color(0xFF223114),
      secondary: Color(0xFFE07A4A),
      secondaryContainer: Color(0xFFFBE0D2),
      onSecondaryContainer: Color(0xFF5A2D16),
      tertiary: Color(0xFFF0BE4B),
      tertiaryContainer: Color(0xFFFCEBBF),
      onTertiaryContainer: Color(0xFF4F3B08),
      surface: Color(0xFFFBF7EF),
      surfaceLow: Color(0xFFFFFCF6),
      surfaceHigh: Color(0xFFF6F0E4),
      surfaceHighest: Color(0xFFECE2D2),
      outline: Color(0xFF938A7D),
      outlineVariant: Color(0xFFE1D6C6),
      gradientEnd: Color(0xFFF7F0DF),
    ),
    CookbukThemePreset(
      id: 'sage',
      label: 'Salbei',
      seedColor: Color(0xFF4F7C4F),
      primary: Color(0xFF2F6B3F),
      primaryContainer: Color(0xFFD4EBCF),
      onPrimaryContainer: Color(0xFF0B2A14),
      secondary: Color(0xFF5E8E62),
      secondaryContainer: Color(0xFFE0F0D9),
      onSecondaryContainer: Color(0xFF16351A),
      tertiary: Color(0xFF7A8F4C),
      tertiaryContainer: Color(0xFFE6EFC8),
      onTertiaryContainer: Color(0xFF24310C),
      surface: Color(0xFFF4F8EF),
      surfaceLow: Color(0xFFFBFFF7),
      surfaceHigh: Color(0xFFEAF2E2),
      surfaceHighest: Color(0xFFD9E5D0),
      outline: Color(0xFF75866F),
      outlineVariant: Color(0xFFC9D8C1),
      gradientEnd: Color(0xFFE3EEDB),
    ),
    CookbukThemePreset(
      id: 'tomato',
      label: 'Tomate',
      seedColor: Color(0xFFC94A3A),
      primary: Color(0xFFB94334),
      primaryContainer: Color(0xFFFFDAD3),
      onPrimaryContainer: Color(0xFF4E130B),
      secondary: Color(0xFF5E7C42),
      secondaryContainer: Color(0xFFE1EACB),
      onSecondaryContainer: Color(0xFF1D2B12),
      tertiary: Color(0xFFC18A2E),
      tertiaryContainer: Color(0xFFF8E4B7),
      onTertiaryContainer: Color(0xFF402A03),
      surface: Color(0xFFFFF7F3),
      surfaceLow: Color(0xFFFFFCF9),
      surfaceHigh: Color(0xFFF8EDE7),
      surfaceHighest: Color(0xFFECDCD3),
      outline: Color(0xFF96857D),
      outlineVariant: Color(0xFFE4D0C7),
      gradientEnd: Color(0xFFFBE9E0),
    ),
    CookbukThemePreset(
      id: 'blueberry',
      label: 'Blaubeere',
      seedColor: Color(0xFF5650A5),
      primary: Color(0xFF46439B),
      primaryContainer: Color(0xFFE2DFFF),
      onPrimaryContainer: Color(0xFF17134A),
      secondary: Color(0xFF6D4E9A),
      secondaryContainer: Color(0xFFEBDDFB),
      onSecondaryContainer: Color(0xFF291244),
      tertiary: Color(0xFF315F9D),
      tertiaryContainer: Color(0xFFDCE8FF),
      onTertiaryContainer: Color(0xFF0B2345),
      surface: Color(0xFFF7F5FF),
      surfaceLow: Color(0xFFFDFBFF),
      surfaceHigh: Color(0xFFEEEAF8),
      surfaceHighest: Color(0xFFE0DAEE),
      outline: Color(0xFF837F9A),
      outlineVariant: Color(0xFFD4CEE5),
      gradientEnd: Color(0xFFEAE6F9),
    ),
    CookbukThemePreset(
      id: 'sesame',
      label: 'Sesam',
      seedColor: Color(0xFF8B7A48),
      primary: Color(0xFF736332),
      primaryContainer: Color(0xFFECE2B8),
      onPrimaryContainer: Color(0xFF282008),
      secondary: Color(0xFF3F7568),
      secondaryContainer: Color(0xFFCBECE3),
      onSecondaryContainer: Color(0xFF092720),
      tertiary: Color(0xFFB86545),
      tertiaryContainer: Color(0xFFF7DCCF),
      onTertiaryContainer: Color(0xFF471D0E),
      surface: Color(0xFFFAF7EE),
      surfaceLow: Color(0xFFFFFCF6),
      surfaceHigh: Color(0xFFF1ECE0),
      surfaceHighest: Color(0xFFE4DCCB),
      outline: Color(0xFF8F8878),
      outlineVariant: Color(0xFFDCD3C1),
      gradientEnd: Color(0xFFF0E9D8),
    ),
  ];

  static CookbukThemePreset byId(String id) {
    for (final preset in presets) {
      if (preset.id == id) return preset;
    }
    return presets.first;
  }
}
