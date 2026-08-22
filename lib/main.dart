import 'package:flutter/material.dart';
import 'package:recipe_capturer/app_router.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF5E8E3E),
          brightness: Brightness.light,
        ).copyWith(
          primary: const Color(0xFF557A36),
          onPrimary: Colors.white,
          onPrimaryContainer: const Color(0xFF223114),
          primaryContainer: const Color(0xFFE2ECCC),
          secondary: const Color(0xFFE07A4A),
          onSecondary: Colors.white,
          secondaryContainer: const Color(0xFFFBE0D2),
          onSecondaryContainer: const Color(0xFF5A2D16),
          tertiary: const Color(0xFFF0BE4B),
          onTertiary: Colors.white,
          tertiaryContainer: const Color(0xFFFCEBBF),
          onTertiaryContainer: const Color(0xFF4F3B08),
          surface: const Color(0xFFFBF7EF),
          onSurface: const Color(0xFF21211D),
          onSurfaceVariant: const Color(0xFF6B6960),
          surfaceContainerLowest: const Color(0xFFFFFFFF),
          surfaceContainerLow: const Color(0xFFFFFCF6),
          surfaceContainer: const Color(0xFFFEFAF2),
          surfaceContainerHigh: const Color(0xFFF6F0E4),
          surfaceContainerHighest: const Color(0xFFECE2D2),
          outline: const Color(0xFF938A7D),
          outlineVariant: const Color(0xFFE1D6C6),
        );

    final base = ThemeData(useMaterial3: true, colorScheme: colorScheme);

    final textTheme = base.textTheme.copyWith(
      displaySmall: base.textTheme.displaySmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -1.4,
      ),
      headlineSmall: base.textTheme.headlineSmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.9,
      ),
      titleLarge: base.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      titleMedium: base.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      titleSmall: base.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
      bodyLarge: base.textTheme.bodyLarge?.copyWith(height: 1.35),
      bodyMedium: base.textTheme.bodyMedium?.copyWith(height: 1.35),
      bodySmall: base.textTheme.bodySmall?.copyWith(height: 1.3),
      labelLarge: base.textTheme.labelLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      ),
    );

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        popupMenuTheme: PopupMenuThemeData(
          color: colorScheme.surfaceContainerLow,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: colorScheme.onSurface,
          contentTextStyle: textTheme.bodyMedium?.copyWith(
            color: colorScheme.surface,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: colorScheme.surfaceContainerHigh,
          selectedColor: colorScheme.primaryContainer,
          disabledColor: colorScheme.surfaceContainerHighest,
          labelStyle: TextStyle(color: colorScheme.onSurface),
          secondaryLabelStyle: TextStyle(color: colorScheme.onPrimaryContainer),
          checkmarkColor: colorScheme.onPrimaryContainer,
          side: BorderSide(color: colorScheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        dividerTheme: DividerThemeData(
          color: colorScheme.outlineVariant.withValues(alpha: 0.75),
        ),
      ),
      builder: (context, child) {
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colorScheme.surface,
                const Color(0xFFFFFBF3),
                const Color(0xFFF7F0DF),
              ],
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      routerConfig: router,
    );
  }
}
