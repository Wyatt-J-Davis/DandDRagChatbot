import 'package:flutter/material.dart';

class ReferenceChip extends StatelessWidget {
  final int index;
  final VoidCallback? onTap;

  const ReferenceChip({super.key, required this.index, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text('Source $index'),
      onPressed: onTap,
    );
  }
}
