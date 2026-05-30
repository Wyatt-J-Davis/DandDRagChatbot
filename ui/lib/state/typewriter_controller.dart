import 'dart:async';

import 'package:flutter/foundation.dart';

class TypewriterController extends ChangeNotifier {
  final String fullText;
  final Duration interval;

  int _currentLength = 0;
  Timer? _timer;

  TypewriterController({
    required this.fullText,
    this.interval = const Duration(milliseconds: 2),
  });

  String get displayedText => fullText.substring(0, _currentLength);
  bool get isDone => _currentLength >= fullText.length;

  void start() {
    if (isDone) return;
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) {
      if (_currentLength < fullText.length) {
        _currentLength++;
        notifyListeners();
      } else {
        _timer?.cancel();
        _timer = null;
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
