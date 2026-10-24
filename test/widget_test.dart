import 'package:flutter_test/flutter_test.dart';
import 'package:challenge_land/app.dart';

void main() {
  testWidgets('Challenge Land app starts with Arabic splash', (tester) async {
    await tester.pumpWidget(const ChallengeLandApp());
    expect(find.text('أرض التحدي'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('الدخول كضيف'), findsOneWidget);
  });
}
