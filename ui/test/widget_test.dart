import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:ttrpg_chatbot/loading_screen.dart';
import 'package:ttrpg_chatbot/main.dart';

void main() {
  testWidgets('App shows LoadingScreen while backend is pending',
      (WidgetTester tester) async {
    final completer = Completer<void>();

    await tester.pumpWidget(TTRPGChatbotApp(backendReady: completer.future));

    expect(find.byType(LoadingScreen), findsOneWidget);

    // Complete the future so the timeout timer is cancelled before teardown.
    completer.complete();
    await tester.pumpAndSettle();
  });
}
