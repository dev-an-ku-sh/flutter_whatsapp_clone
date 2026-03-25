import 'package:flutter_test/flutter_test.dart';
import 'package:chatapp/main.dart';

void main() {
  testWidgets('App starts without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const ChatApp());
    // The app should render without errors
    expect(find.byType(ChatApp), findsOneWidget);
  });
}
