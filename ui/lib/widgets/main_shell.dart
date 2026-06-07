import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

import '../pages/note_editor_page.dart';
import '../pages/qa_page.dart';
import '../pages/summary_page.dart';
import '../services/chat_service.dart';
import '../services/file_picker_service.dart';
import '../services/model_service.dart';
import '../services/note_content_service.dart';
import '../services/note_export_service.dart';
import '../services/party_service.dart';
import '../services/summary_service.dart';
import '../services/upload_service.dart';
import '../services/user_preferences_service.dart';
import '../services/status_service.dart';
import '../services/vectorize_service.dart';
import '../state/app_state_notifier.dart';
import '../state/operation_manager.dart';
import 'menu_sidebar.dart';
import 'settings_popup.dart';

class MainShell extends StatefulWidget {
  final AppStateNotifier appState;
  final ModelService modelService;
  final UserPreferencesService? prefsService;
  final FilePickerService? pickerService;
  final UploadService? uploadService;
  final ChatService? chatService;
  final SummaryService? summaryService;
  final VectorizeService? vectorizeService;
  final NoteContentService? noteContentService;
  final NoteExportService? noteExportService;
  final StatusService? statusService;
  final PartyService? partyService;

  const MainShell({
    super.key,
    required this.appState,
    required this.modelService,
    this.prefsService,
    this.pickerService,
    this.uploadService,
    this.chatService,
    this.summaryService,
    this.vectorizeService,
    this.noteContentService,
    this.noteExportService,
    this.statusService,
    this.partyService,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;
  bool _noteEditorDarkMode = false;
  bool _sidebarCollapsed = false;
  late final QuillController _noteController;
  late final ScrollController _editorScrollController;
  double _currentScrollOffset = 0.0;
  late final OperationManager _operationManager;

  late Future<List<String>> _modelsFuture;

  @override
  void initState() {
    super.initState();
    _noteController = QuillController.basic();
    _editorScrollController = ScrollController();
    _editorScrollController.addListener(() {
      if (_editorScrollController.hasClients) {
        _currentScrollOffset = _editorScrollController.offset;
      }
    });
    _modelsFuture = widget.modelService
        .fetchModels()
        .catchError((_) => <String>[]);
    _operationManager = OperationManager(
      appState: widget.appState,
      chatService: widget.chatService,
      uploadService: widget.uploadService,
      vectorizeService: widget.vectorizeService,
      summaryService: widget.summaryService,
      onUploadSuccess: _loadNotes,
    );
    if (widget.prefsService != null) {
      widget.appState.addListener(_savePreferences);
      _initialize();
    } else {
      _loadNotes();
    }
    _loadStatus();
    _loadParty();
  }

  @override
  void dispose() {
    _operationManager.dispose();
    _savePreferences();
    _editorScrollController.dispose();
    _noteController.dispose();
    widget.appState.removeListener(_savePreferences);
    super.dispose();
  }

  Future<void> _initialize() async {
    await _applyStoredPreferences();
    await _loadNotes();
  }

  Future<void> _applyStoredPreferences() async {
    final prefs = await widget.prefsService!.load();
    if (!mounted) return;
    setState(() {
      _noteEditorDarkMode = prefs.darkMode;
      _sidebarCollapsed = prefs.sidebarCollapsed;
    });
    _currentScrollOffset = prefs.scrollOffset;
    widget.appState.setSelectedModel(prefs.model);
    widget.appState.setTemperature(prefs.temperature);
  }

  void _savePreferences() {
    widget.prefsService?.save(UserPreferences(
      model: widget.appState.selectedModel,
      temperature: widget.appState.temperature,
      darkMode: _noteEditorDarkMode,
      scrollOffset: _currentScrollOffset,
      sidebarCollapsed: _sidebarCollapsed,
    ));
  }

  void _setSidebarCollapsed(bool collapsed) {
    setState(() => _sidebarCollapsed = collapsed);
    _savePreferences();
  }

  void _onConversationSelected(String id) {
    widget.appState.setActiveConversation(id);
    _onDestinationSelected(0);
  }

  void _onNewChat() {
    widget.appState.startNewChat();
    _onDestinationSelected(0);
  }

  Future<void> _onRenameConversation(String id) async {
    final matches = widget.appState.conversations.where((c) => c.id == id);
    if (matches.isEmpty) return;
    final controller = TextEditingController(text: matches.first.title);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename conversation'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName != null && newName.trim().isNotEmpty) {
      widget.appState.renameConversation(id, newName);
    }
  }

  void _onArchiveConversation(String id) {
    widget.appState.toggleArchiveConversation(id);
  }

  Future<void> _onDeleteConversation(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete conversation'),
        content: const Text(
            'This conversation will be permanently deleted. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      widget.appState.deleteConversation(id);
    }
  }

  void _onDestinationSelected(int index) {
    setState(() => _selectedIndex = index);
    if (index == 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_editorScrollController.hasClients) return;
        if (_currentScrollOffset <= 0) return;
        final maxExtent = _editorScrollController.position.maxScrollExtent;
        _editorScrollController.jumpTo(
            _currentScrollOffset.clamp(0.0, maxExtent));
      });
    }
  }

  Future<void> _loadParty() async {
    if (widget.partyService == null) return;
    try {
      final (:members, :noteTaker) = await widget.partyService!.fetchPartyMembers();
      if (!mounted) return;
      widget.appState.setPartyMembers(members);
      widget.appState.setNoteTaker(noteTaker);
    } catch (_) {}
  }

  Future<void> _loadStatus() async {
    if (widget.statusService == null) return;
    try {
      final hasNotes = await widget.statusService!.fetchHasNotes();
      if (!mounted) return;
      widget.appState.setHasNotes(hasNotes);
    } catch (_) {}
  }

  Future<void> _loadNotes() async {
    if (widget.noteContentService == null) return;
    final text = await widget.noteContentService!.fetchNotes();
    if (!mounted || text.isEmpty) return;
    final len = _noteController.document.length;
    _noteController.replaceText(
      0,
      len > 0 ? len - 1 : 0,
      text,
      const TextSelection.collapsed(offset: 0),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_editorScrollController.hasClients) return;
      if (_currentScrollOffset <= 0) return;
      final maxExtent = _editorScrollController.position.maxScrollExtent;
      if (maxExtent > 0) {
        _editorScrollController.jumpTo(
            _currentScrollOffset.clamp(0.0, maxExtent));
      }
    });
  }

  Widget _buildPage() {
    switch (_selectedIndex) {
      case 0:
        return QAPage(
          appState: widget.appState,
          operationManager: _operationManager,
        );
      case 1:
        return SummaryPage(
          appState: widget.appState,
          operationManager: _operationManager,
        );
      case 2:
        return NoteEditorPage(
          controller: _noteController,
          darkMode: _noteEditorDarkMode,
          scrollController: _editorScrollController,
          operationManager: _operationManager,
          noteContentService: widget.noteContentService,
          noteExportService: widget.noteExportService,
          filePickerService: widget.pickerService,
          onToggleDarkMode: () {
            setState(() => _noteEditorDarkMode = !_noteEditorDarkMode);
            _savePreferences();
          },
        );
      default:
        return QAPage(
          appState: widget.appState,
          operationManager: _operationManager,
        );
    }
  }

  void _retryFetchModels() {
    setState(() {
      _modelsFuture = widget.modelService
          .fetchModels()
          .catchError((_) => <String>[]);
    });
  }

  void _openSettings() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: SettingsPopup(
              appState: widget.appState,
              operationManager: _operationManager,
              modelsFuture: _modelsFuture,
              onModelRetry: _retryFetchModels,
              pickerService: widget.pickerService ?? FilePickerService(),
              onUploadSuccess: _loadNotes,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _sidebarCollapsed ? _buildCollapsed() : _buildExpanded(),
    );
  }

  Widget _buildExpanded() {
    return Row(
      children: [
        ListenableBuilder(
          listenable: widget.appState,
          builder: (context, _) => MenuSidebar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onDestinationSelected,
            onCollapse: () => _setSidebarCollapsed(true),
            onOpenSettings: _openSettings,
            conversations: widget.appState.recentConversations,
            archivedConversations: widget.appState.archivedConversations,
            activeConversationId: widget.appState.activeConversationId,
            onConversationSelected: _onConversationSelected,
            onNewChat: _onNewChat,
            onRenameConversation: _onRenameConversation,
            onArchiveConversation: _onArchiveConversation,
            onDeleteConversation: _onDeleteConversation,
          ),
        ),
        const VerticalDivider(thickness: 1, width: 1),
        Expanded(child: _buildPage()),
      ],
    );
  }

  Widget _buildCollapsed() {
    return Stack(
      children: [
        // Left padding keeps the floating hamburger from covering the
        // top-left controls of any page.
        Padding(
          padding: const EdgeInsets.only(left: 56),
          child: _buildPage(),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: Material(
            elevation: 2,
            shape: const CircleBorder(),
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            child: IconButton(
              icon: const Icon(Icons.menu),
              tooltip: 'Open menu',
              onPressed: () => _setSidebarCollapsed(false),
            ),
          ),
        ),
      ],
    );
  }
}
