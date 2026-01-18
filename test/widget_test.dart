import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:recipe_capturer/main.dart';

void main() {
  testWidgets('Title is "Recipes"', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our counter starts at 0.
    expect(find.text('Recipes'), findsOneWidget);
  });

  testWidgets('navigates to /new page and expect title to be New Recipe Page', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our counter starts at 0.
    expect(find.text('Recipes'), findsOneWidget);

    await tester.tap(find.byType(FloatingActionButton));

    await tester.pumpAndSettle();

    expect(find.text('New Recipe Page'), findsOneWidget);
  });
}
