import 'package:flutter_test/flutter_test.dart';
import 'package:umlstudio_mobile/main.dart';

void main() {
  testWidgets('UmlStudioMobileApp builds smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const UmlStudioMobileApp());
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('UmlStudio Live'), findsOneWidget);
  });
}
