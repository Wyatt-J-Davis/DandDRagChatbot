import 'package:flutter/material.dart';

class LoadingScreen extends StatelessWidget {
  final String statusLabel;

  const LoadingScreen({
    super.key,
    this.statusLabel = 'Starting backend…',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(statusLabel, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }
}
