import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:ttrpg_chatbot/services/chat_service.dart';
import 'package:ttrpg_chatbot/services/summary_service.dart';
import 'package:ttrpg_chatbot/services/upload_service.dart';
import 'package:ttrpg_chatbot/services/vectorize_service.dart';
import 'package:ttrpg_chatbot/state/app_state_notifier.dart';
import 'package:ttrpg_chatbot/state/operation_manager.dart';

// --- Chat service fakes ---

class _HangingChatService extends ChatService {
  @override
  Stream<ChatEvent> chat({
    required String question,
    required String model,
    required double temperature,
  }) =>
      StreamController<ChatEvent>().stream;
}

class _AnswerChatService extends ChatService {
  final String answer;
  _AnswerChatService([this.answer = 'test answer']);

  @override
  Stream<ChatEvent> chat({
    required String question,
    required String model,
    required double temperature,
  }) async* {
    yield ChatAnswerEvent(answer: answer, sources: []);
  }
}

class _ErrorChatService extends ChatService {
  @override
  Stream<ChatEvent> chat({
    required String question,
    required String model,
    required double temperature,
  }) async* {
    yield ChatErrorEvent(message: 'Model not found');
  }
}

class _SourcedAnswerChatService extends ChatService {
  final List<ChatSource> sources;
  _SourcedAnswerChatService(this.sources);

  @override
  Stream<ChatEvent> chat({
    required String question,
    required String model,
    required double temperature,
  }) async* {
    yield ChatAnswerEvent(answer: 'answer', sources: sources);
  }
}

// --- Upload service fakes ---

class _HangingUploadService extends UploadService {
  final StreamController<UploadEvent> controller =
      StreamController<UploadEvent>();

  @override
  Stream<UploadEvent> uploadNotes(String _) => controller.stream;
}

class _DoneUploadService extends UploadService {
  @override
  Stream<UploadEvent> uploadNotes(String _) async* {
    yield UploadDoneEvent();
  }
}

class _ProgressUploadService extends UploadService {
  @override
  Stream<UploadEvent> uploadNotes(String _) async* {
    yield UploadProgressEvent(progress: 50, message: '50%');
    yield UploadDoneEvent();
  }
}

class _ErrorUploadService extends UploadService {
  @override
  Stream<UploadEvent> uploadNotes(String _) async* {
    yield UploadErrorEvent(message: 'File not found');
  }
}

// --- Vectorize service fakes ---

class _HangingVectorizeService extends VectorizeService {
  final StreamController<VectorizeEvent> controller =
      StreamController<VectorizeEvent>();

  @override
  Stream<VectorizeEvent> vectorize(String _) => controller.stream;
}

class _DoneVectorizeService extends VectorizeService {
  @override
  Stream<VectorizeEvent> vectorize(String _) async* {
    yield VectorizeDoneEvent();
  }
}

class _ProgressVectorizeService extends VectorizeService {
  @override
  Stream<VectorizeEvent> vectorize(String _) async* {
    yield VectorizeProgressEvent(progress: 40, message: '40%');
    yield VectorizeDoneEvent();
  }
}

class _ErrorVectorizeService extends VectorizeService {
  @override
  Stream<VectorizeEvent> vectorize(String _) async* {
    yield VectorizeErrorEvent(message: 'DB error');
  }
}

// --- Summary service fakes ---

class _HangingSummaryService extends SummaryService {
  final StreamController<SummaryEvent> controller =
      StreamController<SummaryEvent>();

  @override
  Stream<SummaryEvent> generate({
    required String model,
    required List<String> partyMembers,
    required double temperature,
  }) =>
      controller.stream;

  @override
  Future<SummaryResult?> fetchSummary() async => null;
}

class _ProgressSummaryService extends SummaryService {
  final StreamController<SummaryEvent> controller =
      StreamController<SummaryEvent>();

  @override
  Stream<SummaryEvent> generate({
    required String model,
    required List<String> partyMembers,
    required double temperature,
  }) {
    controller.add(
        SummaryProgressEvent(progress: 30, message: 'Summarizing section 1...'));
    return controller.stream;
  }

  @override
  Future<SummaryResult?> fetchSummary() async => null;
}

class _DoneSummaryService extends SummaryService {
  @override
  Stream<SummaryEvent> generate({
    required String model,
    required List<String> partyMembers,
    required double temperature,
  }) async* {
    yield SummaryDoneEvent();
  }

  @override
  Future<SummaryResult?> fetchSummary() async =>
      SummaryResult(summary: 'The campaign summary.');
}

class _ErrorSummaryService extends SummaryService {
  @override
  Stream<SummaryEvent> generate({
    required String model,
    required List<String> partyMembers,
    required double temperature,
  }) async* {
    yield SummaryErrorEvent(message: 'Model not found');
  }

  @override
  Future<SummaryResult?> fetchSummary() async => null;
}

class _FetchSummaryService extends SummaryService {
  final SummaryResult? result;
  int fetchCount = 0;

  _FetchSummaryService(this.result);

  @override
  Stream<SummaryEvent> generate({
    required String model,
    required List<String> partyMembers,
    required double temperature,
  }) async* {}

  @override
  Future<SummaryResult?> fetchSummary() async {
    fetchCount++;
    return result;
  }
}

class _CapturingTemperatureSummaryService extends SummaryService {
  double? capturedTemperature;

  @override
  Stream<SummaryEvent> generate({
    required String model,
    required List<String> partyMembers,
    required double temperature,
  }) async* {
    capturedTemperature = temperature;
  }

  @override
  Future<SummaryResult?> fetchSummary() async => null;
}

// --- Helpers ---

OperationManager makeManager({
  AppStateNotifier? appState,
  ChatService? chatService,
  UploadService? uploadService,
  VectorizeService? vectorizeService,
  SummaryService? summaryService,
  void Function()? onUploadSuccess,
  void Function()? onVectorizeSuccess,
  void Function(SummaryResult)? onSummaryComplete,
}) =>
    OperationManager(
      appState: appState ?? AppStateNotifier(),
      chatService: chatService,
      uploadService: uploadService,
      vectorizeService: vectorizeService,
      summaryService: summaryService,
      onUploadSuccess: onUploadSuccess,
      onVectorizeSuccess: onVectorizeSuccess,
      onSummaryComplete: onSummaryComplete,
    );

void main() {
  // ------------------------------------------------------------------ chat --
  group('OperationManager (chat)', () {
    test('chatStatus is idle initially', () {
      expect(makeManager().chatStatus, OperationStatus.idle);
    });

    test('isChatRunning is false initially', () {
      expect(makeManager().isChatRunning, isFalse);
    });

    test('chatStatus becomes running after startChat', () {
      final manager = makeManager(chatService: _HangingChatService());
      manager.startChat(question: 'q', model: 'llama3', temperature: 0.5);
      expect(manager.chatStatus, OperationStatus.running);
    });

    test('isChatRunning is true while running', () {
      final manager = makeManager(chatService: _HangingChatService());
      manager.startChat(question: 'q', model: 'llama3', temperature: 0.5);
      expect(manager.isChatRunning, isTrue);
    });

    test('notifies listeners when chat starts', () {
      int calls = 0;
      final manager = makeManager(chatService: _HangingChatService());
      manager.addListener(() => calls++);
      manager.startChat(question: 'q', model: 'llama3', temperature: 0.5);
      expect(calls, greaterThanOrEqualTo(1));
    });

    test('chatStatus becomes done after ChatAnswerEvent', () async {
      final manager = makeManager(chatService: _AnswerChatService());
      manager.startChat(question: 'q', model: 'llama3', temperature: 0.5);
      await Future<void>.delayed(Duration.zero);
      expect(manager.chatStatus, OperationStatus.done);
    });

    test('chatStatus becomes error after ChatErrorEvent', () async {
      final manager = makeManager(chatService: _ErrorChatService());
      manager.startChat(question: 'q', model: 'llama3', temperature: 0.5);
      await Future<void>.delayed(Duration.zero);
      expect(manager.chatStatus, OperationStatus.error);
    });

    test('chatError is set after ChatErrorEvent', () async {
      final manager = makeManager(chatService: _ErrorChatService());
      manager.startChat(question: 'q', model: 'llama3', temperature: 0.5);
      await Future<void>.delayed(Duration.zero);
      expect(manager.chatError, 'Model not found');
    });

    test('assistant ChatMessage is added to appState on answer', () async {
      final appState = AppStateNotifier();
      final manager =
          makeManager(appState: appState, chatService: _AnswerChatService('reply'));
      manager.startChat(question: 'q', model: 'llama3', temperature: 0.5);
      await Future<void>.delayed(Duration.zero);
      expect(
        appState.chatHistory.any((m) =>
            m.sender == ChatSender.assistant && m.text == 'reply'),
        isTrue,
      );
    });

    test('error ChatMessage is added to appState on error', () async {
      final appState = AppStateNotifier();
      final manager =
          makeManager(appState: appState, chatService: _ErrorChatService());
      manager.startChat(question: 'q', model: 'llama3', temperature: 0.5);
      await Future<void>.delayed(Duration.zero);
      expect(
        appState.chatHistory.any((m) =>
            m.sender == ChatSender.assistant &&
            m.text.startsWith('Error:')),
        isTrue,
      );
    });

    test('sources are attached to chat message', () async {
      final appState = AppStateNotifier();
      final sources = [const ChatSource(content: 'chunk', date: '2024-01-01')];
      final manager = makeManager(
        appState: appState,
        chatService: _SourcedAnswerChatService(sources),
      );
      manager.startChat(question: 'q', model: 'llama3', temperature: 0.5);
      await Future<void>.delayed(Duration.zero);
      final msg = appState.chatHistory.firstWhere(
          (m) => m.sender == ChatSender.assistant);
      expect(msg.sources.first.date, '2024-01-01');
    });

    test('status retained independent of any page (no widget lifecycle)', () {
      final manager = makeManager(chatService: _HangingChatService());
      manager.startChat(question: 'q', model: 'llama3', temperature: 0.5);
      // No widget creation/destruction — status must survive
      expect(manager.chatStatus, OperationStatus.running);
    });
  });

  // --------------------------------------------------------------- upload --
  group('OperationManager (upload)', () {
    test('uploadStatus is idle initially', () {
      expect(makeManager().uploadStatus, OperationStatus.idle);
    });

    test('isUploadRunning is false initially', () {
      expect(makeManager().isUploadRunning, isFalse);
    });

    test('uploadStatus becomes running after startUpload', () {
      final manager = makeManager(uploadService: _HangingUploadService());
      manager.startUpload(path: '/notes.txt');
      expect(manager.uploadStatus, OperationStatus.running);
    });

    test('uploadProgress updates on progress events', () async {
      final manager = makeManager(uploadService: _ProgressUploadService());
      manager.startUpload(path: '/notes.txt');
      await Future<void>.delayed(Duration.zero);
      expect(manager.uploadProgress, greaterThanOrEqualTo(0));
    });

    test('uploadStatus becomes done after UploadDoneEvent', () async {
      final manager = makeManager(uploadService: _DoneUploadService());
      manager.startUpload(path: '/notes.txt');
      await Future<void>.delayed(Duration.zero);
      expect(manager.uploadStatus, OperationStatus.done);
    });

    test('uploadStatus becomes error after UploadErrorEvent', () async {
      final manager = makeManager(uploadService: _ErrorUploadService());
      manager.startUpload(path: '/notes.txt');
      await Future<void>.delayed(Duration.zero);
      expect(manager.uploadStatus, OperationStatus.error);
    });

    test('uploadError is set on error', () async {
      final manager = makeManager(uploadService: _ErrorUploadService());
      manager.startUpload(path: '/notes.txt');
      await Future<void>.delayed(Duration.zero);
      expect(manager.uploadError, 'File not found');
    });

    test('appState.hasNotes is set to true on upload success', () async {
      final appState = AppStateNotifier();
      final manager =
          makeManager(appState: appState, uploadService: _DoneUploadService());
      manager.startUpload(path: '/notes.txt');
      await Future<void>.delayed(Duration.zero);
      expect(appState.hasNotes, isTrue);
    });

    test('onUploadSuccess callback fires on done', () async {
      bool called = false;
      final manager = makeManager(
        uploadService: _DoneUploadService(),
        onUploadSuccess: () => called = true,
      );
      manager.startUpload(path: '/notes.txt');
      await Future<void>.delayed(Duration.zero);
      expect(called, isTrue);
    });

    test('onUploadSuccess not called on error', () async {
      bool called = false;
      final manager = makeManager(
        uploadService: _ErrorUploadService(),
        onUploadSuccess: () => called = true,
      );
      manager.startUpload(path: '/notes.txt');
      await Future<void>.delayed(Duration.zero);
      expect(called, isFalse);
    });

    test('notifies listeners on progress change', () async {
      int calls = 0;
      final manager = makeManager(uploadService: _ProgressUploadService());
      manager.addListener(() => calls++);
      manager.startUpload(path: '/notes.txt');
      await Future<void>.delayed(Duration.zero);
      expect(calls, greaterThan(1));
    });

    test('upload status retained independent of any page', () {
      final manager = makeManager(uploadService: _HangingUploadService());
      manager.startUpload(path: '/notes.txt');
      expect(manager.uploadStatus, OperationStatus.running);
    });
  });

  // ------------------------------------------------------------- vectorize --
  group('OperationManager (vectorize)', () {
    test('vectorizeStatus is idle initially', () {
      expect(makeManager().vectorizeStatus, OperationStatus.idle);
    });

    test('vectorizeStatus becomes running after startVectorize', () {
      final manager = makeManager(vectorizeService: _HangingVectorizeService());
      manager.startVectorize(text: 'notes text');
      expect(manager.vectorizeStatus, OperationStatus.running);
    });

    test('vectorizeProgress updates on progress events', () async {
      final manager = makeManager(vectorizeService: _ProgressVectorizeService());
      manager.startVectorize(text: 'notes');
      await Future<void>.delayed(Duration.zero);
      expect(manager.vectorizeProgress, greaterThanOrEqualTo(0));
    });

    test('vectorizeStatus becomes done after VectorizeDoneEvent', () async {
      final manager = makeManager(vectorizeService: _DoneVectorizeService());
      manager.startVectorize(text: 'notes');
      await Future<void>.delayed(Duration.zero);
      expect(manager.vectorizeStatus, OperationStatus.done);
    });

    test('vectorizeStatus becomes error after VectorizeErrorEvent', () async {
      final manager = makeManager(vectorizeService: _ErrorVectorizeService());
      manager.startVectorize(text: 'notes');
      await Future<void>.delayed(Duration.zero);
      expect(manager.vectorizeStatus, OperationStatus.error);
    });

    test('vectorizeError is set on error', () async {
      final manager = makeManager(vectorizeService: _ErrorVectorizeService());
      manager.startVectorize(text: 'notes');
      await Future<void>.delayed(Duration.zero);
      expect(manager.vectorizeError, 'DB error');
    });

    test('onVectorizeSuccess callback fires on done', () async {
      bool called = false;
      final manager = makeManager(
        vectorizeService: _DoneVectorizeService(),
        onVectorizeSuccess: () => called = true,
      );
      manager.startVectorize(text: 'notes');
      await Future<void>.delayed(Duration.zero);
      expect(called, isTrue);
    });

    test('vectorize status retained independent of any page', () {
      final manager = makeManager(vectorizeService: _HangingVectorizeService());
      manager.startVectorize(text: 'notes');
      expect(manager.vectorizeStatus, OperationStatus.running);
    });

    test('appState.hasNotes is set to true after VectorizeDoneEvent', () async {
      final appState = AppStateNotifier();
      final manager = makeManager(
        appState: appState,
        vectorizeService: _DoneVectorizeService(),
      );
      manager.startVectorize(text: 'notes');
      await Future<void>.delayed(Duration.zero);
      expect(appState.hasNotes, isTrue);
    });
  });

  // --------------------------------------------------------------- summary --
  group('OperationManager (summary)', () {
    test('summaryStatus is idle initially', () {
      expect(makeManager().summaryStatus, OperationStatus.idle);
    });

    test('summaryStatus becomes running after startSummary', () {
      final manager = makeManager(summaryService: _HangingSummaryService());
      manager.startSummary(model: 'llama3', partyMembers: [], temperature: 0.7);
      expect(manager.summaryStatus, OperationStatus.running);
    });

    test('summaryProgress updates on progress events', () async {
      final manager = makeManager(summaryService: _ProgressSummaryService());
      manager.startSummary(model: 'llama3', partyMembers: [], temperature: 0.7);
      await Future<void>.delayed(Duration.zero);
      expect(manager.summaryProgress, 30);
    });

    test('summaryProgressMessage is updated from events', () async {
      final manager = makeManager(summaryService: _ProgressSummaryService());
      manager.startSummary(model: 'llama3', partyMembers: [], temperature: 0.7);
      await Future<void>.delayed(Duration.zero);
      expect(manager.summaryProgressMessage, 'Summarizing section 1...');
    });

    test('summaryPhase is "Map" for Summarizing messages', () async {
      final manager = makeManager(summaryService: _ProgressSummaryService());
      manager.startSummary(model: 'llama3', partyMembers: [], temperature: 0.7);
      await Future<void>.delayed(Duration.zero);
      expect(manager.summaryPhase, 'Map');
    });

    test('summaryStatus becomes done after SummaryDoneEvent', () async {
      final manager = makeManager(summaryService: _DoneSummaryService());
      manager.startSummary(model: 'llama3', partyMembers: [], temperature: 0.7);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(manager.summaryStatus, OperationStatus.done);
    });

    test('summaryResult is stored after SummaryDoneEvent', () async {
      final manager = makeManager(summaryService: _DoneSummaryService());
      manager.startSummary(model: 'llama3', partyMembers: [], temperature: 0.7);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(manager.summaryResult?.summary, 'The campaign summary.');
    });

    test('summaryStatus becomes error after SummaryErrorEvent', () async {
      final manager = makeManager(summaryService: _ErrorSummaryService());
      manager.startSummary(model: 'llama3', partyMembers: [], temperature: 0.7);
      await Future<void>.delayed(Duration.zero);
      expect(manager.summaryStatus, OperationStatus.error);
    });

    test('summaryError is set on error', () async {
      final manager = makeManager(summaryService: _ErrorSummaryService());
      manager.startSummary(model: 'llama3', partyMembers: [], temperature: 0.7);
      await Future<void>.delayed(Duration.zero);
      expect(manager.summaryError, 'Model not found');
    });

    test('onSummaryComplete callback fires with result', () async {
      SummaryResult? received;
      final manager = makeManager(
        summaryService: _DoneSummaryService(),
        onSummaryComplete: (r) => received = r,
      );
      manager.startSummary(model: 'llama3', partyMembers: [], temperature: 0.7);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(received?.summary, 'The campaign summary.');
    });

    test('summary status retained independent of any page', () {
      final manager = makeManager(summaryService: _HangingSummaryService());
      manager.startSummary(model: 'llama3', partyMembers: [], temperature: 0.7);
      expect(manager.summaryStatus, OperationStatus.running);
    });

    test('startSummary forwards temperature to service', () async {
      final svc = _CapturingTemperatureSummaryService();
      final manager = makeManager(summaryService: svc);
      manager.startSummary(model: 'llama3', partyMembers: [], temperature: 0.3);
      await Future<void>.delayed(Duration.zero);
      expect(svc.capturedTemperature, 0.3);
    });

    test('loadSummary stores result in summaryResult', () async {
      final service = _FetchSummaryService(SummaryResult(summary: 'Existing.'));
      final manager = makeManager(summaryService: service);
      await manager.loadSummary();
      expect(manager.summaryResult?.summary, 'Existing.');
    });

    test('loadSummary does not change status when already running', () async {
      final svc = _HangingSummaryService();
      final manager = makeManager(summaryService: svc);
      manager.startSummary(model: 'llama3', partyMembers: [], temperature: 0.7);
      expect(manager.summaryStatus, OperationStatus.running);
      // loadSummary should be a no-op when running
      await manager.loadSummary();
      expect(manager.summaryStatus, OperationStatus.running);
      expect(manager.summaryResult, isNull);
      svc.controller.close();
    });
  });

  // ------------------------------------------------------- global busy gate --
  group('OperationManager (global busy gate)', () {
    test('isAnyHeavyOperationRunning is false when nothing runs', () {
      expect(makeManager().isAnyHeavyOperationRunning, isFalse);
    });

    test('isAnyHeavyOperationRunning is true while chat runs', () {
      final manager = makeManager(chatService: _HangingChatService());
      manager.startChat(question: 'q', model: 'llama3', temperature: 0.5);
      expect(manager.isAnyHeavyOperationRunning, isTrue);
    });

    test('isAnyHeavyOperationRunning is true while upload runs', () {
      final manager = makeManager(uploadService: _HangingUploadService());
      manager.startUpload(path: '/notes.txt');
      expect(manager.isAnyHeavyOperationRunning, isTrue);
    });

    test('isAnyHeavyOperationRunning is true while vectorize runs', () {
      final manager = makeManager(vectorizeService: _HangingVectorizeService());
      manager.startVectorize(text: 'notes');
      expect(manager.isAnyHeavyOperationRunning, isTrue);
    });

    test('isAnyHeavyOperationRunning is true while summary runs', () {
      final manager = makeManager(summaryService: _HangingSummaryService());
      manager.startSummary(model: 'llama3', partyMembers: [], temperature: 0.7);
      expect(manager.isAnyHeavyOperationRunning, isTrue);
    });

    test('isAnyHeavyOperationRunning becomes false when chat finishes', () async {
      final manager = makeManager(chatService: _AnswerChatService());
      manager.startChat(question: 'q', model: 'llama3', temperature: 0.5);
      await Future<void>.delayed(Duration.zero);
      expect(manager.isAnyHeavyOperationRunning, isFalse);
    });

    test('starting upload makes isAnyHeavyOperationRunning true, isChatRunning stays false', () {
      final manager = makeManager(
        uploadService: _HangingUploadService(),
        chatService: _HangingChatService(),
      );
      manager.startUpload(path: '/notes.txt');
      expect(manager.isAnyHeavyOperationRunning, isTrue);
      expect(manager.isChatRunning, isFalse);
    });
  });

  // -------------------------------------------------------------- phase detection
  group('OperationManager (phase detection)', () {
    test('Summarizing message yields Map phase', () async {
      final ctrl = StreamController<SummaryEvent>();
      final svc = _HangingSummaryService();
      final manager = makeManager(summaryService: svc);
      manager.startSummary(model: 'llama3', partyMembers: [], temperature: 0.7);
      svc.controller.add(SummaryProgressEvent(
          progress: 10, message: 'Summarizing section 2...'));
      await Future<void>.delayed(Duration.zero);
      expect(manager.summaryPhase, 'Map');
      ctrl.close();
    });

    test('Combining message yields Reduce phase', () async {
      final svc = _HangingSummaryService();
      final manager = makeManager(summaryService: svc);
      manager.startSummary(model: 'llama3', partyMembers: [], temperature: 0.7);
      svc.controller.add(SummaryProgressEvent(
          progress: 50, message: 'Combining summaries (pass 1)...'));
      await Future<void>.delayed(Duration.zero);
      expect(manager.summaryPhase, 'Reduce');
    });

    test('Writing message yields Synthesis phase', () async {
      final svc = _HangingSummaryService();
      final manager = makeManager(summaryService: svc);
      manager.startSummary(model: 'llama3', partyMembers: [], temperature: 0.7);
      svc.controller.add(SummaryProgressEvent(
          progress: 90, message: 'Writing final campaign summary...'));
      await Future<void>.delayed(Duration.zero);
      expect(manager.summaryPhase, 'Synthesis');
    });
  });
}
