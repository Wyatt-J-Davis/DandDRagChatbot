import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../services/vectorize_service.dart';

class VectorizeButton extends StatefulWidget {
  final QuillController controller;
  final VectorizeService vectorizeService;

  VectorizeButton({
    super.key,
    required this.controller,
    VectorizeService? vectorizeService,
  }) : vectorizeService = vectorizeService ?? VectorizeService();

  @override
  State<VectorizeButton> createState() => _VectorizeButtonState();
}

class _VectorizeButtonState extends State<VectorizeButton> {
  bool _isVectorizing = false;
  int _progress = 0;
  String? _error;
  bool _success = false;

  Future<void> _startVectorize() async {
    final text = widget.controller.document.toPlainText();
    setState(() {
      _isVectorizing = true;
      _progress = 0;
      _error = null;
      _success = false;
    });
    await for (final event in widget.vectorizeService.vectorize(text)) {
      if (!mounted) return;
      if (event is VectorizeProgressEvent) {
        setState(() => _progress = event.progress);
      } else if (event is VectorizeDoneEvent) {
        setState(() {
          _isVectorizing = false;
          _success = true;
        });
      } else if (event is VectorizeErrorEvent) {
        setState(() {
          _isVectorizing = false;
          _error = event.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: _isVectorizing ? null : _startVectorize,
          child: const Text('Vectorize'),
        ),
        if (_isVectorizing) ...[
          const SizedBox(height: 8),
          LinearProgressIndicator(value: _progress / 100),
        ],
        if (_success) ...[
          const SizedBox(height: 4),
          const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 16),
              SizedBox(width: 4),
              Text('Vectorization complete'),
            ],
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 4),
          Text(
            _error!,
            style: const TextStyle(color: Colors.red),
          ),
        ],
      ],
    );
  }
}
