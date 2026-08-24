import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainShellPage extends StatelessWidget {
  const MainShellPage({super.key, required this.child, required this.location});

  final Widget child;
  final String location;

  int get _currentIndex {
    if (location.startsWith('/week')) return 1;
    if (location.startsWith('/recipes')) return 2;
    if (location.startsWith('/shopping')) return 3;
    if (location.startsWith('/status')) return 4;
    return 0;
  }

  void _go(BuildContext context, int index) {
    final path = switch (index) {
      0 => '/today',
      1 => '/week',
      2 => '/recipes',
      3 => '/shopping',
      _ => '/status',
    };
    if (location != path) context.go(path);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => _go(context, index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Heute',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_view_week_outlined),
            selectedIcon: Icon(Icons.calendar_view_week),
            label: 'Woche',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Rezepte',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_basket_outlined),
            selectedIcon: Icon(Icons.shopping_basket),
            label: 'Einkauf',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Status',
          ),
        ],
      ),
    );
  }
}
