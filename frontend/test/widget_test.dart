import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cookbuk/data/demo_recipes.dart';
import 'package:cookbuk/data/in_memory_recipe_repository.dart';
import 'package:cookbuk/main.dart';
import 'package:cookbuk/ui/pages/today_page.dart';

void main() {
  testWidgets('shows Today as the home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Heute'), findsWidgets);
    expect(find.text('Was essen wir heute?'), findsOneWidget);
    expect(find.text('Frühstück'), findsOneWidget);
  });

  testWidgets('navigates to manual recipe form', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.text('Rezepte'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit_note_outlined));

    await tester.pumpAndSettle();

    expect(find.text('Neues Rezept'), findsOneWidget);
  });

  testWidgets('clears a Today meal after revealing trash action', (
    WidgetTester tester,
  ) async {
    final repo = InMemoryRecipeRepository();
    for (final recipe in demoRecipes) {
      await repo.add(recipe);
    }

    await tester.pumpWidget(MaterialApp(home: TodayPage(repo: repo)));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Frühstück'), const Offset(-180, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline).first);
    await tester.pumpAndSettle();

    expect(find.text('Nichts geplant'), findsOneWidget);
  });
}
