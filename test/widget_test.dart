import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:recipe_capturer/main.dart';

void main() {
  testWidgets('shows recipe library home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Rezepte'), findsWidgets);
    expect(find.text('Rezept hinzufügen'), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);
  });

  testWidgets('navigates to manual recipe form', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.tap(find.byIcon(Icons.edit_note_outlined));

    await tester.pumpAndSettle();

    expect(find.text('Neues Rezept'), findsOneWidget);
  });
}
