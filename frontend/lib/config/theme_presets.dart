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

  ThemeData buildTheme({Brightness brightness = Brightness.light}) {
    final isDark = brightness == Brightness.dark;
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: brightness,
        ).copyWith(
          primary: isDark ? _darkAccent(primary) : primary,
          onPrimary: isDark ? const Color(0xFF171511) : Colors.white,
          onPrimaryContainer: isDark
              ? _darkOnContainer(primaryContainer)
              : onPrimaryContainer,
          primaryContainer: isDark ? _darkContainer(primary) : primaryContainer,
          secondary: isDark ? _darkAccent(secondary) : secondary,
          onSecondary: isDark ? const Color(0xFF171511) : Colors.white,
          secondaryContainer: isDark
              ? _darkContainer(secondary)
              : secondaryContainer,
          onSecondaryContainer: isDark
              ? _darkOnContainer(secondaryContainer)
              : onSecondaryContainer,
          tertiary: isDark ? _darkAccent(tertiary) : tertiary,
          onTertiary: isDark ? const Color(0xFF171511) : Colors.white,
          tertiaryContainer: isDark
              ? _darkContainer(tertiary)
              : tertiaryContainer,
          onTertiaryContainer: isDark
              ? _darkOnContainer(tertiaryContainer)
              : onTertiaryContainer,
          surface: isDark ? _darkSurface : _lightSurface,
          onSurface: isDark ? _darkOnSurface : _lightOnSurface,
          onSurfaceVariant: isDark
              ? _darkOnSurfaceVariant
              : _lightOnSurfaceVariant,
          surfaceContainerLowest: isDark
              ? _darkSurfaceLowest
              : _lightSurfaceLowest,
          surfaceContainerLow: isDark ? _darkSurfaceLow : _lightSurfaceLow,
          surfaceContainer: isDark ? _darkSurfaceLow : _lightSurfaceLow,
          surfaceContainerHigh: isDark ? _darkSurfaceHigh : _lightSurfaceHigh,
          surfaceContainerHighest: isDark
              ? _darkSurfaceHighest
              : _lightSurfaceHighest,
          outline: isDark ? _darkOutline : _lightOutline,
          outlineVariant: isDark ? _darkOutlineVariant : _lightOutlineVariant,
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
        backgroundColor: isDark
            ? colorScheme.surfaceContainerHighest
            : colorScheme.onSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: isDark ? colorScheme.onSurface : colorScheme.surface,
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

  static const _lightSurface = Color(0xFFFBF8F2);
  static const _lightSurfaceLowest = Color(0xFFFFFFFF);
  static const _lightSurfaceLow = Color(0xFFFFFCF7);
  static const _lightSurfaceHigh = Color(0xFFF5EFE6);
  static const _lightSurfaceHighest = Color(0xFFEDE3D6);
  static const _lightOnSurface = Color(0xFF21211D);
  static const _lightOnSurfaceVariant = Color(0xFF6B6960);
  static const _lightOutline = Color(0xFF90877B);
  static const _lightOutlineVariant = Color(0xFFE1D7C9);

  static const _darkSurface = Color(0xFF151411);
  static const _darkSurfaceLowest = Color(0xFF0F0E0C);
  static const _darkSurfaceLow = Color(0xFF1C1A16);
  static const _darkSurfaceHigh = Color(0xFF26231E);
  static const _darkSurfaceHighest = Color(0xFF312C25);
  static const _darkOnSurface = Color(0xFFF3EDE4);
  static const _darkOnSurfaceVariant = Color(0xFFC9C0B4);
  static const _darkOutline = Color(0xFF998F82);
  static const _darkOutlineVariant = Color(0xFF494239);

  static Color _darkAccent(Color color) {
    return Color.lerp(color, Colors.white, 0.34)!;
  }

  static Color _darkContainer(Color color) {
    return Color.lerp(_darkSurfaceHighest, color, 0.42)!;
  }

  static Color _darkOnContainer(Color color) {
    return Color.lerp(color, Colors.white, 0.76)!;
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
      seedColor: Color(0xFF527A57),
      primary: Color(0xFF2F7047),
      primaryContainer: Color(0xFFD6EBD8),
      onPrimaryContainer: Color(0xFF0D2B18),
      secondary: Color(0xFF73945D),
      secondaryContainer: Color(0xFFE1EED4),
      onSecondaryContainer: Color(0xFF233516),
      tertiary: Color(0xFF43806D),
      tertiaryContainer: Color(0xFFD3ECE5),
      onTertiaryContainer: Color(0xFF0D3128),
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
      seedColor: Color(0xFF5E7C42),
      primary: Color(0xFF5E7C42),
      primaryContainer: Color(0xFFE1EACB),
      onPrimaryContainer: Color(0xFF1D2B12),
      secondary: Color(0xFFB94334),
      secondaryContainer: Color(0xFFFFDAD3),
      onSecondaryContainer: Color(0xFF4E130B),
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
      seedColor: Color(0xFF5756B0),
      primary: Color(0xFF5149A6),
      primaryContainer: Color(0xFFE4E0FF),
      onPrimaryContainer: Color(0xFF19144D),
      secondary: Color(0xFF7D4FA3),
      secondaryContainer: Color(0xFFEFDDFC),
      onSecondaryContainer: Color(0xFF311247),
      tertiary: Color(0xFF3867A9),
      tertiaryContainer: Color(0xFFDDE8FF),
      onTertiaryContainer: Color(0xFF0D2547),
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
      seedColor: Color(0xFF3F7568),
      primary: Color(0xFF3F7568),
      primaryContainer: Color(0xFFCBECE3),
      onPrimaryContainer: Color(0xFF092720),
      secondary: Color(0xFF736332),
      secondaryContainer: Color(0xFFECE2B8),
      onSecondaryContainer: Color(0xFF282008),
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
