import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cookbuk/main.dart';

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
}
