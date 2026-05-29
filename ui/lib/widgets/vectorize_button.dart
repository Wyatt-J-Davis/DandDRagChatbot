import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../state/operation_manager.dart';

class VectorizeButton extends StatefulWidget {
  final QuillController controller;
  final OperationManager operationManager;

  const VectorizeButton({
    super.key,
    required this.controller,
    required this.operationManager,
  });

  @override
  State<VectorizeButton> createState() => _VectorizeButtonState();
}

class _VectorizeButtonState extends State<VectorizeButton> {
  OperationStatus _previousStatus = OperationStatus.idle;
  bool _showSuccess = false;

  @override
  void initState() {
    super.initState();
    widget.operationManager.addListener(_onManagerChange);
    _syncState();
  }

  @override
  void didUpdateWidget(VectorizeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.operationManager != widget.operationManager) {
      oldWidget.operationManager.removeListener(_onManagerChange);
      widget.operationManager.addListener(_onManagerChange);
      _syncState();
    }
  }

  @override
  void dispose() {
    widget.operationManager.removeListener(_onManagerChange);
    super.dispose();
  }

  void _syncState() {
    _previousStatus = widget.operationManager.vectorizeStatus;
    _showSuccess =
        widget.operationManager.vectorizeStatus == OperationStatus.done;
  }

  void _onManagerChange() {
    if (!mounted) return;
    final status = widget.operationManager.vectorizeStatus;
    if (status == OperationStatus.done &&
        _previousStatus == OperationStatus.running) {
      _showSuccess = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notes vectorized successfully')),
      );
    }
    if (status == OperationStatus.running) {
      _showSuccess = false;
    }
    _previousStatus = status;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isVectorizing = widget.operationManager.isVectorizeRunning;
    final progress = widget.operationManager.vectorizeProgress;
    final error = widget.operationManager.vectorizeError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ElevatedButton(
          onPressed: isVectorizing
              ? null
              : () {
                  final text = widget.controller.document.toPlainText();
                  widget.operationManager.startVectorize(text: text);
                },
          child: const Text('Vectorize'),
        ),
        if (isVectorizing) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: 100,
            child: LinearProgressIndicator(value: progress / 100),
          ),
        ],
        if (_showSuccess) ...[
          const SizedBox(height: 4),
          Row(
            children: const [
              Icon(Icons.check_circle, color: Colors.green, size: 16),
              SizedBox(width: 4),
              Flexible(child: Text('Vectorization complete')),
            ],
          ),
        ],
        if (error != null && !isVectorizing && !_showSuccess) ...[
          const SizedBox(height: 4),
          Text(
            error,
            style: const TextStyle(color: Colors.red),
          ),
        ],
      ],
    );
  }
}
