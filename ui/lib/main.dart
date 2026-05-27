import 'package:flutter/material.dart';

import 'loading_screen.dart';
import 'services/backend_service.dart';
import 'services/model_service.dart';
import 'state/app_state_notifier.dart';
import 'widgets/app_shell.dart';
import 'widgets/main_shell.dart';

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
    final appState = AppStateNotifier();
    final modelService = ModelService();

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
        child: MainShell(appState: appState, modelService: modelService),
      ),
    );
  }
}
