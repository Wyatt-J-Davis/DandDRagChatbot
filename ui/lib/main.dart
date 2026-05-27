import 'package:flutter/material.dart';

import 'loading_screen.dart';
import 'services/backend_service.dart';
import 'widgets/app_shell.dart';

BackendService? _backendService;

Future<void> _startBackend() async {
  _backendService = BackendService(executablePath: 'backend/ttrpg_backend.exe');
  await _backendService!.start();
  return _backendService!.ready;
}

void main() {
  final backendReady = _startBackend();
  runApp(TTRPGChatbotApp(backendReady: backendReady));
}

class TTRPGChatbotApp extends StatelessWidget {
  final Future<void> backendReady;

  const TTRPGChatbotApp({super.key, required this.backendReady});

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
      home: AppShell(
        ready: backendReady,
        child: const _PlaceholderHome(),
      ),
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
