import 'package:flutter_test/flutter_test.dart';

import 'package:recipe_capturer/main.dart';

void main() {
  testWidgets('Title is "Recipes"', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our counter starts at 0.
    expect(find.text('Recipes'), findsOneWidget);
  });
}
