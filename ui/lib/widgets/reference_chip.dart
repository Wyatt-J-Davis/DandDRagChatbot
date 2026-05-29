import 'package:flutter/material.dart';

class ReferenceChip extends StatelessWidget {
  final int index;
  final String? date;
  final VoidCallback? onTap;

  const ReferenceChip({super.key, required this.index, this.date, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(date ?? 'Source $index'),
      onPressed: onTap,
    );
  }
}
