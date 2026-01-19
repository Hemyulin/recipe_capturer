import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:recipe_capturer/main.dart';

void main() {
  testWidgets('Title is "Recipes"', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    expect(find.text('Recipes'), findsOneWidget);
  });
}
