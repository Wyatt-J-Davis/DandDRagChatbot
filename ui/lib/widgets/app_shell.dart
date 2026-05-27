import 'dart:async';

import 'package:flutter/material.dart';

import '../loading_screen.dart';

enum _ShellPhase { loading, ready, error, timedOut }

class AppShell extends StatefulWidget {
  final Future<void> ready;
  final Widget child;
  final Duration timeout;

  const AppShell({
    super.key,
    required this.ready,
    required this.child,
    this.timeout = const Duration(seconds: 30),
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  _ShellPhase _phase = _ShellPhase.loading;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _timeoutTimer = Timer(widget.timeout, _onTimeout);
    widget.ready.then((_) => _onReady()).catchError((_) => _onError());
  }

  void _onReady() {
    _timeoutTimer?.cancel();
    if (mounted) setState(() => _phase = _ShellPhase.ready);
  }

  void _onError() {
    _timeoutTimer?.cancel();
    if (mounted) setState(() => _phase = _ShellPhase.error);
  }

  void _onTimeout() {
    if (mounted) setState(() => _phase = _ShellPhase.timedOut);
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (_phase) {
      _ShellPhase.loading => const LoadingScreen(),
      _ShellPhase.ready => widget.child,
      _ShellPhase.error => const _ErrorScreen(
          message: 'Failed to start backend. Please restart the application.',
        ),
      _ShellPhase.timedOut => const _ErrorScreen(
          message:
              'Backend failed to start in time. Please restart the application.',
        ),
    };
  }
}

class _ErrorScreen extends StatelessWidget {
  final String message;

  const _ErrorScreen({required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(message, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
