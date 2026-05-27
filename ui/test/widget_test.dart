import 'package:flutter_test/flutter_test.dart';

import 'package:ttrpg_chatbot/main.dart';

void main() {
  testWidgets('App renders placeholder home text', (WidgetTester tester) async {
    await tester.pumpWidget(const TTRPGChatbotApp());

    expect(find.text('TTRPG Campaign Chatbot'), findsOneWidget);
  });
}
