import 'package:flutter/material.dart';

import '../models/conversation.dart';
import 'sidebar_panel.dart';

/// Unified, Ollama-style left sidebar: a collapse hamburger, the page
/// navigation destinations, the recent chat history list, a collapsible
/// Archived section, and Settings pinned at the bottom.
class MenuSidebar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onCollapse;
  final VoidCallback onOpenSettings;
  final List<Conversation> conversations;
  final List<Conversation> archivedConversations;
  final String? activeConversationId;
  final ValueChanged<String> onConversationSelected;
  final VoidCallback onNewChat;
  final ValueChanged<String> onRenameConversation;
  final ValueChanged<String> onArchiveConversation;
  final ValueChanged<String> onDeleteConversation;

  const MenuSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onCollapse,
    required this.onOpenSettings,
    this.conversations = const [],
    this.archivedConversations = const [],
    this.activeConversationId,
    required this.onConversationSelected,
    required this.onNewChat,
    required this.onRenameConversation,
    required this.onArchiveConversation,
    required this.onDeleteConversation,
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
              child: ListView(
                children: [
                  for (final conversation in conversations)
                    _ConversationTile(
                      conversation: conversation,
                      selected: conversation.id == activeConversationId,
                      onTap: () => onConversationSelected(conversation.id),
                      onRename: () => onRenameConversation(conversation.id),
                      onToggleArchive: () =>
                          onArchiveConversation(conversation.id),
                      onDelete: () => onDeleteConversation(conversation.id),
                    ),
                  if (archivedConversations.isNotEmpty)
                    ExpansionTile(
                      title: const Text('Archived'),
                      leading: const Icon(Icons.archive_outlined),
                      childrenPadding: EdgeInsets.zero,
                      tilePadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        for (final conversation in archivedConversations)
                          _ConversationTile(
                            conversation: conversation,
                            selected:
                                conversation.id == activeConversationId,
                            onTap: () =>
                                onConversationSelected(conversation.id),
                            onRename: () =>
                                onRenameConversation(conversation.id),
                            onToggleArchive: () =>
                                onArchiveConversation(conversation.id),
                            onDelete: () =>
                                onDeleteConversation(conversation.id),
                          ),
                      ],
                    ),
                ],
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

/// A single conversation row whose `⋮` overflow menu (Rename, Archive/
/// Unarchive, Delete) is revealed on hover.
class _ConversationTile extends StatefulWidget {
  final Conversation conversation;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback onToggleArchive;
  final VoidCallback onDelete;

  const _ConversationTile({
    required this.conversation,
    required this.selected,
    required this.onTap,
    required this.onRename,
    required this.onToggleArchive,
    required this.onDelete,
  });

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  bool _hovering = false;
  // Keeps the overflow button mounted while its menu is open, even after the
  // pointer leaves the row (otherwise PopupMenuButton drops the selection).
  bool _menuOpen = false;

  @override
  Widget build(BuildContext context) {
    final showMenu = _hovering || _menuOpen;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: ListTile(
        title: Text(
          widget.conversation.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        selected: widget.selected,
        onTap: widget.onTap,
        trailing: showMenu
            ? PopupMenuButton<_ConversationAction>(
                icon: const Icon(Icons.more_vert),
                tooltip: 'Conversation options',
                onOpened: () => setState(() => _menuOpen = true),
                onCanceled: () => setState(() => _menuOpen = false),
                onSelected: (action) {
                  setState(() => _menuOpen = false);
                  switch (action) {
                    case _ConversationAction.rename:
                      widget.onRename();
                    case _ConversationAction.archive:
                      widget.onToggleArchive();
                    case _ConversationAction.delete:
                      widget.onDelete();
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: _ConversationAction.rename,
                    child: Text('Rename'),
                  ),
                  PopupMenuItem(
                    value: _ConversationAction.archive,
                    child: Text(
                        widget.conversation.archived ? 'Unarchive' : 'Archive'),
                  ),
                  const PopupMenuItem(
                    value: _ConversationAction.delete,
                    child: Text('Delete'),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

enum _ConversationAction { rename, archive, delete }
