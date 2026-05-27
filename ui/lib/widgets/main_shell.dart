import 'package:flutter/material.dart';

import '../pages/note_editor_page.dart';
import '../pages/qa_page.dart';
import '../pages/summary_page.dart';
import '../services/model_service.dart';
import '../state/app_state_notifier.dart';
import 'model_selector_dropdown.dart';
import 'sidebar_panel.dart';

class MainShell extends StatefulWidget {
  final AppStateNotifier appState;
  final ModelService modelService;

  const MainShell({
    super.key,
    required this.appState,
    required this.modelService,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  late Future<List<String>> _modelsFuture;

  static const List<NavigationRailDestination> _destinations = [
    NavigationRailDestination(
      icon: Icon(Icons.chat_outlined),
      selectedIcon: Icon(Icons.chat),
      label: Text('Q&A'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.summarize_outlined),
      selectedIcon: Icon(Icons.summarize),
      label: Text('Summary'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.edit_note_outlined),
      selectedIcon: Icon(Icons.edit_note),
      label: Text('Note Editor'),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _modelsFuture = widget.modelService.fetchModels();
  }

  Widget _buildPage() {
    switch (_selectedIndex) {
      case 0:
        return const QAPage();
      case 1:
        return const SummaryPage();
      case 2:
        return const NoteEditorPage();
      default:
        return const QAPage();
    }
  }

  void _retryFetchModels() {
    setState(() {
      _modelsFuture = widget.modelService.fetchModels();
    });
  }

  Widget? _buildSidebarChild() {
    if (_selectedIndex != 0) return null;
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: ModelSelectorDropdown(
        modelsFuture: _modelsFuture,
        appState: widget.appState,
        onRetry: _retryFetchModels,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) =>
                setState(() => _selectedIndex = index),
            labelType: NavigationRailLabelType.all,
            destinations: _destinations,
          ),
          const VerticalDivider(thickness: 1, width: 1),
          SidebarPanel(child: _buildSidebarChild()),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: _buildPage()),
        ],
      ),
    );
  }
}
