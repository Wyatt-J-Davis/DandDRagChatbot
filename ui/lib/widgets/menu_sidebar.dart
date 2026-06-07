import 'package:flutter/material.dart';

import '../models/conversation.dart';
import 'sidebar_panel.dart';

/// Unified, Ollama-style left sidebar: a collapse hamburger, the page
/// navigation destinations, the recent chat history list, and Settings
/// pinned at the bottom.
class MenuSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onCollapse;
  final VoidCallback onOpenSettings;
  final List<Conversation> conversations;
  final String? activeConversationId;
  final ValueChanged<String> onConversationSelected;
  final VoidCallback onNewChat;

  const MenuSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onCollapse,
    required this.onOpenSettings,
    this.conversations = const [],
    this.activeConversationId,
    required this.onConversationSelected,
    required this.onNewChat,
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: onNewChat,
                  icon: const Icon(Icons.add),
                  label: const Text('New chat'),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: conversations.length,
                itemBuilder: (context, i) {
                  final conversation = conversations[i];
                  return ListTile(
                    title: Text(
                      conversation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    selected: conversation.id == activeConversationId,
                    onTap: () => onConversationSelected(conversation.id),
                  );
                },
              ),
            ),
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
