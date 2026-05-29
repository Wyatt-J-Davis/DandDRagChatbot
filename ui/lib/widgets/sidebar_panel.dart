import 'package:flutter/material.dart';

class SidebarPanel extends StatelessWidget {
  static const double panelWidth = 240.0;

  final Widget? child;

  const SidebarPanel({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: panelWidth,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        child: child,
      ),
    );
  }
}
