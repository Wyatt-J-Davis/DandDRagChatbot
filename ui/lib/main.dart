import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import 'services/backend_service.dart';
import 'services/model_service.dart';
import 'services/party_service.dart';
import 'services/status_service.dart';
import 'services/user_preferences_service.dart';
import 'state/app_state_notifier.dart';
import 'widgets/app_shell.dart';
import 'widgets/main_shell.dart';

BackendService? _backendService;

Future<void> _startBackend() async {
  _backendService = BackendService(executablePath: 'backend/ttrpg_backend.exe');
  await _backendService!.start();
  return _backendService!.ready;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefsService = UserPreferencesService(file: File('user_data.json'));
  final initialPrefs = await prefsService.load();

  final backendReady = _startBackend();
  runApp(TTRPGChatbotApp(
    backendReady: backendReady,
    prefsService: prefsService,
    initialPrefs: initialPrefs,
  ));
}

class TTRPGChatbotApp extends StatelessWidget {
  final Future<void> backendReady;
  final UserPreferencesService? prefsService;
  final UserPreferences? initialPrefs;

  const TTRPGChatbotApp({
    super.key,
    required this.backendReady,
    this.prefsService,
    this.initialPrefs,
  });

  @override
  Widget build(BuildContext context) {
    final appState = AppStateNotifier(
      initialModel: initialPrefs?.model,
      initialTemperature: initialPrefs?.temperature ?? 0.5,
    );
    final modelService = ModelService();
    final statusService = StatusService();
    final partyService = PartyService();

    return MaterialApp(
      title: 'TTRPG Campaign Chatbot',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: FlutterQuillLocalizations.localizationsDelegates,
      supportedLocales: FlutterQuillLocalizations.supportedLocales,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
      ),
      home: AppShell(
        ready: backendReady,
        child: MainShell(
          appState: appState,
          modelService: modelService,
          prefsService: prefsService,
          statusService: statusService,
          partyService: partyService,
        ),
      ),
    );
  }
}
