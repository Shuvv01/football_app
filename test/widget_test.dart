import 'package:flutter_test/flutter_test.dart';

import 'package:football_app/main.dart';

void main() {
  testWidgets('SHUVAM FC app starts', (WidgetTester tester) async {
    await tester.pumpWidget(const ShuvamFootballClubApp());

    expect(find.text('SHUVAM FC'), findsWidgets);
    expect(find.text('Home'), findsWidgets);
  });
}
