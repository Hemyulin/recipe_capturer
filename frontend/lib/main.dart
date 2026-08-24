import 'package:flutter/material.dart';
import 'package:cookbuk/app_router.dart';
import 'package:cookbuk/config/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await themeController.load();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
        final preset = themeController.preset;
        final theme = preset.buildTheme();
        final colorScheme = theme.colorScheme;

        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: theme,
          builder: (context, child) {
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.surface,
                    colorScheme.surfaceContainerLow,
                    preset.gradientEnd,
                  ],
                ),
              ),
              child: child ?? const SizedBox.shrink(),
            );
          },
          routerConfig: router,
        );
      },
    );
  }
}
