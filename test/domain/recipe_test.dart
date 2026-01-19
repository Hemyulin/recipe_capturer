import 'package:flutter_test/flutter_test.dart';
import 'package:recipe_capturer/main.dart';

void main() {
  testWidgets('description', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
  });
}
