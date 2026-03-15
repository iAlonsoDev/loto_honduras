import 'package:flutter_test/flutter_test.dart';
import 'package:loto_honduras/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const LotoHondurasApp());
  });
}
