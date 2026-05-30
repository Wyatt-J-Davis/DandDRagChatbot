import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/chat_service.dart';
import '../services/summary_service.dart';
import '../services/upload_service.dart';
import '../services/vectorize_service.dart';
import 'app_state_notifier.dart';

enum OperationStatus { idle, running, done, error }

class OperationManager extends ChangeNotifier {
  final AppStateNotifier _appState;
  final ChatService _chatService;
  final UploadService _uploadService;
  final VectorizeService _vectorizeService;
  final SummaryService _summaryService;

  void Function()? onUploadSuccess;
  void Function()? onVectorizeSuccess;
  void Function(SummaryResult)? onSummaryComplete;

  // Chat
  StreamSubscription<ChatEvent>? _chatSubscription;
  OperationStatus _chatStatus = OperationStatus.idle;
  String? _chatError;

  // Upload
  StreamSubscription<UploadEvent>? _uploadSubscription;
  OperationStatus _uploadStatus = OperationStatus.idle;
  int _uploadProgress = 0;
  String? _uploadError;

  // Vectorize
  StreamSubscription<VectorizeEvent>? _vectorizeSubscription;
  OperationStatus _vectorizeStatus = OperationStatus.idle;
  int _vectorizeProgress = 0;
  String? _vectorizeError;

  // Summary
  StreamSubscription<SummaryEvent>? _summarySubscription;
  OperationStatus _summaryStatus = OperationStatus.idle;
  int _summaryProgress = 0;
  String _summaryProgressMessage = '';
  String _summaryPhase = '';
  String? _summaryError;
  SummaryResult? _summaryResult;

  OperationManager({
    required AppStateNotifier appState,
    ChatService? chatService,
    UploadService? uploadService,
    VectorizeService? vectorizeService,
    SummaryService? summaryService,
    this.onUploadSuccess,
    this.onVectorizeSuccess,
    this.onSummaryComplete,
  })  : _appState = appState,
        _chatService = chatService ?? ChatService(),
        _uploadService = uploadService ?? UploadService(),
        _vectorizeService = vectorizeService ?? VectorizeService(),
        _summaryService = summaryService ?? SummaryService();

  // ── Chat ──────────────────────────────────────────────────────────────────

  OperationStatus get chatStatus => _chatStatus;
  bool get isChatRunning => _chatStatus == OperationStatus.running;
  String? get chatError => _chatError;

  void startChat({
    required String question,
    required String model,
    required double temperature,
  }) {
    _chatSubscription?.cancel();
    _chatStatus = OperationStatus.running;
    _chatError = null;
    notifyListeners();

    _chatSubscription = _chatService
        .chat(question: question, model: model, temperature: temperature)
        .listen(
      (event) {
        if (event is ChatAnswerEvent) {
          _appState.addChatMessage(ChatMessage(
            sender: ChatSender.assistant,
            text: event.answer,
            sources: event.sources,
          ));
          _chatStatus = OperationStatus.done;
          notifyListeners();
        } else if (event is ChatErrorEvent) {
          _appState.addChatMessage(ChatMessage(
            sender: ChatSender.assistant,
            text: 'Error: ${event.message}',
          ));
          _chatStatus = OperationStatus.error;
          _chatError = event.message;
          notifyListeners();
        }
      },
      onError: (Object e) {
        _chatStatus = OperationStatus.error;
        _chatError = e.toString();
        notifyListeners();
      },
      onDone: () {
        if (_chatStatus == OperationStatus.running) {
          _chatStatus = OperationStatus.done;
          notifyListeners();
        }
      },
    );
  }

  // ── Upload ────────────────────────────────────────────────────────────────

  OperationStatus get uploadStatus => _uploadStatus;
  bool get isUploadRunning => _uploadStatus == OperationStatus.running;
  int get uploadProgress => _uploadProgress;
  String? get uploadError => _uploadError;

  void startUpload({required String path}) {
    _uploadSubscription?.cancel();
    _uploadStatus = OperationStatus.running;
    _uploadProgress = 0;
    _uploadError = null;
    notifyListeners();

    _uploadSubscription = _uploadService.uploadNotes(path).listen(
      (event) {
        if (event is UploadProgressEvent) {
          _uploadProgress = event.progress;
          notifyListeners();
        } else if (event is UploadDoneEvent) {
          _uploadStatus = OperationStatus.done;
          _appState.setHasNotes(true);
          notifyListeners();
          onUploadSuccess?.call();
        } else if (event is UploadErrorEvent) {
          _uploadStatus = OperationStatus.error;
          _uploadError = event.message;
          notifyListeners();
        }
      },
      onError: (Object e) {
        _uploadStatus = OperationStatus.error;
        _uploadError = e.toString();
        notifyListeners();
      },
    );
  }

  // ── Vectorize ─────────────────────────────────────────────────────────────

  OperationStatus get vectorizeStatus => _vectorizeStatus;
  bool get isVectorizeRunning => _vectorizeStatus == OperationStatus.running;
  int get vectorizeProgress => _vectorizeProgress;
  String? get vectorizeError => _vectorizeError;

  void startVectorize({required String text}) {
    _vectorizeSubscription?.cancel();
    _vectorizeStatus = OperationStatus.running;
    _vectorizeProgress = 0;
    _vectorizeError = null;
    notifyListeners();

    _vectorizeSubscription = _vectorizeService.vectorize(text).listen(
      (event) {
        if (event is VectorizeProgressEvent) {
          _vectorizeProgress = event.progress;
          notifyListeners();
        } else if (event is VectorizeDoneEvent) {
          _vectorizeStatus = OperationStatus.done;
          _appState.setHasNotes(true);
          notifyListeners();
          onVectorizeSuccess?.call();
        } else if (event is VectorizeErrorEvent) {
          _vectorizeStatus = OperationStatus.error;
          _vectorizeError = event.message;
          notifyListeners();
        }
      },
      onError: (Object e) {
        _vectorizeStatus = OperationStatus.error;
        _vectorizeError = e.toString();
        notifyListeners();
      },
    );
  }

  // ── Summary ───────────────────────────────────────────────────────────────

  OperationStatus get summaryStatus => _summaryStatus;
  bool get isSummaryRunning => _summaryStatus == OperationStatus.running;
  int get summaryProgress => _summaryProgress;
  String get summaryProgressMessage => _summaryProgressMessage;
  String get summaryPhase => _summaryPhase;
  String? get summaryError => _summaryError;
  SummaryResult? get summaryResult => _summaryResult;

  void startSummary({
    required String model,
    required List<String> partyMembers,
  }) {
    _summarySubscription?.cancel();
    _summaryStatus = OperationStatus.running;
    _summaryProgress = 0;
    _summaryProgressMessage = '';
    _summaryPhase = '';
    _summaryError = null;
    // _summaryResult is intentionally NOT reset here so the previous summary
    // remains visible while regenerating (drives the Regenerate button display)
    notifyListeners();

    _summarySubscription =
        _summaryService.generate(model: model, partyMembers: partyMembers).listen(
      (event) {
        if (event is SummaryProgressEvent) {
          _summaryProgress = event.progress;
          _summaryProgressMessage = event.message;
          _summaryPhase = _detectPhase(event.message);
          notifyListeners();
        } else if (event is SummaryDoneEvent) {
          _summaryService.fetchSummary().then((result) {
            _summaryStatus = OperationStatus.done;
            _summaryResult = result;
            notifyListeners();
            if (result != null) onSummaryComplete?.call(result);
          });
        } else if (event is SummaryErrorEvent) {
          _summaryStatus = OperationStatus.error;
          _summaryError = event.message;
          notifyListeners();
        }
      },
      onError: (Object e) {
        _summaryStatus = OperationStatus.error;
        _summaryError = e.toString();
        notifyListeners();
      },
      onDone: () {
        if (_summaryStatus == OperationStatus.running) {
          _summaryStatus = OperationStatus.done;
          notifyListeners();
        }
      },
    );
  }

  Future<void> loadSummary() async {
    if (_summaryStatus == OperationStatus.running) return;
    final result = await _summaryService.fetchSummary();
    if (result != null) {
      _summaryResult = result;
      notifyListeners();
    }
  }

  static String _detectPhase(String message) {
    if (message.contains('Summarizing')) return 'Map';
    if (message.contains('Combining')) return 'Reduce';
    if (message.contains('Writing') || message.contains('Generating')) {
      return 'Synthesis';
    }
    return '';
  }

  @override
  void dispose() {
    _chatSubscription?.cancel();
    _uploadSubscription?.cancel();
    _vectorizeSubscription?.cancel();
    _summarySubscription?.cancel();
    super.dispose();
  }
}
