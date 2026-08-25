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

        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: preset.buildTheme(),
          darkTheme: preset.buildTheme(brightness: Brightness.dark),
          themeMode: themeController.themeMode,
          builder: (context, child) {
            final colorScheme = Theme.of(context).colorScheme;
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.surface,
                    colorScheme.surface,
                    colorScheme.surfaceContainerLow,
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
