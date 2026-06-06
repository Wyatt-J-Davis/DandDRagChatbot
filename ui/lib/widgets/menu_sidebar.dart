import 'package:flutter/material.dart';

import 'sidebar_panel.dart';

/// Unified, Ollama-style left sidebar: a collapse hamburger, the page
/// navigation destinations, a region reserved for the chat history list
/// (added in a later slice), and Settings pinned at the bottom.
class MenuSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onCollapse;
  final VoidCallback onOpenSettings;

  const MenuSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onCollapse,
    required this.onOpenSettings,
  });

  static const List<({IconData icon, String label})> _destinations = [
    (icon: Icons.lens, label: 'Q&A'),
    (icon: Icons.auto_awesome, label: 'Summary'),
    (icon: Icons.history_edu, label: 'Note Editor'),
  ];

  @override
  Widget build(BuildContext context) {
    return SidebarPanel(
      child: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.menu),
                tooltip: 'Collapse menu',
                onPressed: onCollapse,
              ),
            ),
            for (var i = 0; i < _destinations.length; i++)
              ListTile(
                leading: Icon(_destinations[i].icon),
                title: Text(_destinations[i].label),
                selected: i == selectedIndex,
                onTap: () => onDestinationSelected(i),
              ),
            const Divider(height: 1),
            // Reserved for the chat history list (later slice).
            const Expanded(child: SizedBox.shrink()),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: onOpenSettings,
            ),
          ],
        ),
      ),
    );
  }
}
