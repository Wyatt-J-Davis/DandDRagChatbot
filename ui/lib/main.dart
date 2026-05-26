import 'package:flutter/material.dart';

void main() {
  runApp(const TTRPGChatbotApp());
}

class TTRPGChatbotApp extends StatelessWidget {
  const TTRPGChatbotApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TTRPG Campaign Chatbot',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      home: const _PlaceholderHome(),
    );
  }
}

class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('TTRPG Campaign Chatbot'),
      ),
    );
  }
}
