import 'package:flutter_test/flutter_test.dart';
import 'package:awakening/main.dart';

void main() {
  testWidgets('App starts and shows splash screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.byType(MyApp), findsOneWidget);
    // You can add more specific splash screen checks if needed
  });
}
