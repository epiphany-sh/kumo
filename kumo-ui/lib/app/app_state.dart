import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/changes.dart';
import '../data/workspace_source.dart';
import '../data/models.dart';
import '../theme/palette.dart';
import 'preferences.dart';

enum KumoView {
  terminal('Terminal', '⌘1'),
  files('Files', '⌘2'),
  agents('Agents', '⌘3'),
  tasks('Tasks', '⌘4'),
  git('Git', '⌘5'),
  docs('Docs', '⌘6');

  const KumoView(this.label, this.shortcut);
  final String label;
  final String shortcut;
}

/// App-wide UI state. Everything here changes optimistically in the same
/// frame (kumo.md §5.2); once the daemon exists, it confirms or reverts.
class AppState extends ChangeNotifier {
  /// [prefs] restores the user's settings (theme, translucency, side panel)
  /// and keeps them; without it everything is in memory (tests).
  ///
  /// [workspace] provides namespaces, repos and worktrees: the daemon in the
  /// app, the design mocks when omitted (tests).
  AppState({KumoThemeMode mode = KumoThemeMode.dark, this.demoWallpaper = false, Preferences? prefs, WorkspaceSource? workspace})
      : prefs = prefs ?? Preferences.memory(),
        workspace = workspace ?? MockWorkspaceSource(),
        _mode = mode {
    this.workspace.addListener(_onWorkspaceChanged);
    final p = this.prefs;
    final saved = p.get<String>('theme', '');
    for (final m in KumoThemeMode.values) {
      if (m.name == saved) _mode = m;
    }
    _translucency = p.get<double>('translucency', _translucency).clamp(0.25, 0.9).toDouble();
    _sidePanelRight = p.get<bool>('sidePanel.right', false);
    _sidePanelOpen = p.get<bool>('sidePanel.onLaunch', true);
  }

  /// Persisted user settings. Settings screens read and write through
  /// [setting] / [setSetting]; typed ones also have fields here.
  final Preferences prefs;

  T setting<T>(String key, T fallback) => prefs.get<T>(key, fallback);

  void setSetting(String key, Object? value) {
    prefs.set(key, value);
    notifyListeners();
  }

  KumoThemeMode _mode;
  KumoThemeMode get mode => _mode;
  set mode(KumoThemeMode m) {
    if (m == _mode) return;
    _mode = m;
    prefs.set('theme', m.name);
    notifyListeners();
  }

  /// Cycles dark → light → hybrid.
  void cycleTheme() => mode = KumoThemeMode.values[(_mode.index + 1) % KumoThemeMode.values.length];

  KumoView _view = KumoView.terminal;
  KumoView get view => _view;
  set view(KumoView v) {
    if (v == _view) return;
    _view = v;
    notifyListeners();
  }

  double _translucency = 0.55;
  double get translucency => _translucency;
  set translucency(double v) {
    _translucency = v.clamp(0.25, 0.9);
    prefs.set('translucency', _translucency);
    notifyListeners();
  }

  /// Paints the canvas wallpaper instead of relying on OS translucency.
  bool demoWallpaper;
  void toggleDemoWallpaper() {
    demoWallpaper = !demoWallpaper;
    notifyListeners();
  }

  bool _sidebarVisible = true;
  bool get sidebarVisible => _sidebarVisible;
  void toggleSidebar() {
    _sidebarVisible = !_sidebarVisible;
    notifyListeners();
  }

  /// The selected worktree: its branch (shown) and, with real data, its path
  /// (the identity: `main` exists in every repo). Mocks select by branch.
  String activeWorktree = 'feat/PRC-412-bulk-discounts';
  String? activeWorktreePath;
  void selectWorktree(String branch, {String? path}) {
    activeWorktree = branch;
    activeWorktreePath = path;
    notifyListeners();
  }

  bool isActiveWorktree(Worktree w) => activeWorktreePath != null ? w.path == activeWorktreePath : w.branch == activeWorktree;

  /// Repo of the selected worktree (the first one when none matches).
  Repo? get activeRepo {
    final repos = workspace.repos;
    for (final r in repos) {
      if (worktreesOf(r).any(isActiveWorktree)) return r;
    }
    return repos.firstOrNull;
  }

  /// The selected worktree itself, if it is still there.
  Worktree? get activeWorktreeEntry => activeRepo?.worktrees.where(isActiveWorktree).firstOrNull;

  void _onWorkspaceChanged() {
    if (workspace.error != _lastWorkspaceError) {
      _lastWorkspaceError = workspace.error;
      _workspaceErrorDismissed = false;
    }
    // Nothing selected yet (or it was removed): pick the first main checkout.
    if (activeWorktreeEntry == null) {
      final main = workspace.repos.firstOrNull?.worktrees.where((w) => w.isMain).firstOrNull;
      if (main != null) {
        activeWorktree = main.branch;
        activeWorktreePath = main.path;
      }
    }
    notifyListeners();
  }

  /// Request to open the "New worktree" popover (from ⌘⇧N or the sidebar +).
  final ValueNotifier<int> newWorktreeRequests = ValueNotifier(0);
  void requestNewWorktree() => newWorktreeRequests.value++;

  // ---- Namespaces (sidebar groups of repos) ----

  /// Namespaces, repos and worktrees (see [WorkspaceSource]).
  final WorkspaceSource workspace;

  /// Deleted namespaces still within their undo window.
  final Set<String> _hiddenNamespaces = {};

  List<Namespace> get namespaces => [for (final n in workspace.namespaces) if (!_hiddenNamespaces.contains(n.id)) n];

  Namespace? namespaceById(String id) => namespaces.where((n) => n.id == id).firstOrNull;

  /// Creates a namespace and returns its id.
  String createNamespace(String name, List<String> repos) =>
      workspace.saveNamespace(name: name.trim().isEmpty ? 'untitled' : name.trim(), repos: repos);

  void updateNamespace(String id, {String? name, List<String>? repos, bool? collapsed}) {
    final n = namespaceById(id);
    if (n == null) return;
    workspace.saveNamespace(
      id: id,
      name: (name == null || name.trim().isEmpty) ? n.name : name.trim(),
      repos: repos ?? n.repos,
      collapsed: collapsed ?? n.collapsed,
    );
  }

  void renameNamespace(String id, String name) {
    if (name.trim().isEmpty) return;
    updateNamespace(id, name: name);
  }

  void toggleNamespaceCollapsed(String id) {
    final n = namespaceById(id);
    if (n != null) updateNamespace(id, collapsed: !n.collapsed);
  }

  /// Removes the group only; repos and worktrees stay on disk. Undoable:
  /// the daemon is only told once the undo window closes.
  void deleteNamespace(String id) {
    final n = namespaceById(id);
    if (n == null) return;
    _hiddenNamespaces.add(id);
    _offerUndo(
      'Deleted “${n.name}”',
      () => _hiddenNamespaces.remove(id),
      commit: () {
        _hiddenNamespaces.remove(id);
        workspace.deleteNamespace(id);
      },
    );
  }

  // ---- Worktrees ----

  /// Removed worktrees (`<repo id>:<path>`) still within their undo window.
  final Set<String> _removedWorktrees = {};
  bool isWorktreeRemoved(Repo repo, Worktree w) => _removedWorktrees.contains('${repo.id}:${w.path}');

  /// Visible worktrees of [repo] (deleted ones filtered out).
  List<Worktree> worktreesOf(Repo repo) => [for (final w in repo.worktrees) if (!isWorktreeRemoved(repo, w)) w];

  /// `git worktree remove` (the branch stays), once the undo window closes.
  /// The principal checkout is not a worktree and can't be removed.
  void deleteWorktree(String repoId, String branch) {
    final repo = workspace.repo(repoId);
    final w = repo?.worktrees.where((w) => w.branch == branch).firstOrNull;
    if (repo == null || w == null || w.isMain) return;
    final key = '${repo.id}:${w.path}';
    if (!_removedWorktrees.add(key)) return;
    if (isActiveWorktree(w)) {
      final main = repo.worktrees.where((w) => w.isMain).firstOrNull;
      activeWorktree = main?.branch ?? 'main';
      activeWorktreePath = main == null || activeWorktreePath == null ? null : main.path;
    }
    _offerUndo(
      'Deleted worktree “$branch”',
      () => _removedWorktrees.remove(key),
      commit: () => workspace.removeWorktree(repo, w).then(
            (_) => _removedWorktrees.remove(key),
            // Git refused (e.g. uncommitted changes): show it again.
            onError: (Object _) {
              _removedWorktrees.remove(key);
              notifyListeners();
            },
          ),
    );
  }

  /// The daemon's last error about the workspace, until dismissed.
  String? get workspaceError => _workspaceErrorDismissed ? null : workspace.error;
  bool _workspaceErrorDismissed = false;
  String? _lastWorkspaceError;
  void dismissWorkspaceError() {
    _workspaceErrorDismissed = true;
    notifyListeners();
  }

  // ---- Undo toast ----

  UndoNotice? _undo;
  UndoNotice? get undo => _undo;
  Timer? _undoTimer;
  VoidCallback? _pendingCommit;

  /// Shows an undo toast. [commit] runs when the window closes without an
  /// undo (destructive work happens only then), or when another undoable
  /// action replaces this one.
  void _offerUndo(String message, VoidCallback restore, {VoidCallback? commit}) {
    _undoTimer?.cancel();
    _runPendingCommit();
    _undo = UndoNotice(message, restore);
    _pendingCommit = commit;
    _undoTimer = Timer(const Duration(seconds: 8), dismissUndo);
    notifyListeners();
  }

  void _runPendingCommit() {
    final commit = _pendingCommit;
    _pendingCommit = null;
    commit?.call();
  }

  void undoLast() {
    final u = _undo;
    if (u == null) return;
    _undoTimer?.cancel();
    _undo = null;
    _pendingCommit = null;
    u.restore();
    notifyListeners();
  }

  void dismissUndo() {
    _undoTimer?.cancel();
    if (_undo == null) return;
    _undo = null;
    _runPendingCommit();
    notifyListeners();
  }

  // ---- Side panel (Files / Widgets / Source control) ----

  bool _sidePanelOpen = true;
  bool get sidePanelOpen => _sidePanelOpen;

  /// Side panel to the right of the terminal instead of the left.
  bool _sidePanelRight = false;
  bool get sidePanelRight => _sidePanelRight;
  set sidePanelRight(bool v) {
    if (v == _sidePanelRight) return;
    _sidePanelRight = v;
    prefs.set('sidePanel.right', v);
    notifyListeners();
  }

  /// Whether the side panel starts open (it can always be toggled, ⌥⌘B).
  bool get sidePanelOnLaunch => prefs.get<bool>('sidePanel.onLaunch', true);
  set sidePanelOnLaunch(bool v) => setSetting('sidePanel.onLaunch', v);
  SidePanelTab _sidePanelTab = SidePanelTab.git;
  SidePanelTab get sidePanelTab => _sidePanelTab;

  void toggleSidePanel() {
    _sidePanelOpen = !_sidePanelOpen;
    notifyListeners();
  }

  void showSidePanelTab(SidePanelTab t) {
    _sidePanelTab = t;
    _sidePanelOpen = true;
    notifyListeners();
  }

  // ---- Inspector widgets (the Widgets tab) ----

  List<InspectorWidget> _widgets = const [InspectorWidget.agent, InspectorWidget.changes, InspectorWidget.context];
  List<InspectorWidget> get widgets => List.unmodifiable(_widgets);
  List<InspectorWidget> get availableWidgets => [for (final w in InspectorWidget.values) if (!_widgets.contains(w)) w];

  /// ReorderableListView semantics: [to] is the index before removal.
  void reorderWidget(int from, int to) {
    if (from < 0 || from >= _widgets.length) return;
    final list = [..._widgets];
    final w = list.removeAt(from);
    var at = to > from ? to - 1 : to;
    if (at < 0) at = 0;
    if (at > list.length) at = list.length;
    list.insert(at, w);
    _widgets = list;
    notifyListeners();
  }

  void moveWidget(InspectorWidget w, int delta) {
    final i = _widgets.indexOf(w);
    final j = i + delta;
    if (i < 0 || j < 0 || j >= _widgets.length) return;
    final list = [..._widgets];
    list[i] = list[j];
    list[j] = w;
    _widgets = list;
    notifyListeners();
  }

  void addWidget(InspectorWidget w) {
    if (_widgets.contains(w)) return;
    _widgets = [..._widgets, w];
    notifyListeners();
  }

  void removeWidget(InspectorWidget w) {
    _widgets = [for (final x in _widgets) if (x != w) x];
    notifyListeners();
  }

  bool _agentPaused = false;
  bool get agentPaused => _agentPaused;
  void toggleAgentPaused() {
    _agentPaused = !_agentPaused;
    notifyListeners();
  }

  // ---- File tabs in the Terminal view ----

  final List<String> _openFiles = [];
  List<String> get openFiles => List.unmodifiable(_openFiles);
  String? _activeFile;

  /// The file tab showing, or null when the terminal panes are showing.
  String? get activeFile => _activeFile;

  void openFile(String path) {
    if (!_openFiles.contains(path)) _openFiles.add(path);
    _activeFile = path;
    _view = KumoView.terminal;
    notifyListeners();
  }

  void openAllFiles(Iterable<String> paths) {
    String? first;
    for (final p in paths) {
      first ??= p;
      if (!_openFiles.contains(p)) _openFiles.add(p);
    }
    if (first == null) return;
    _activeFile = first;
    _view = KumoView.terminal;
    notifyListeners();
  }

  void closeFile(String path) {
    final i = _openFiles.indexOf(path);
    if (i < 0) return;
    _openFiles.removeAt(i);
    if (_activeFile == path) _activeFile = _openFiles.isEmpty ? null : _openFiles[i > 0 ? i - 1 : 0];
    notifyListeners();
  }

  /// Back to the terminal panes (a terminal tab was clicked).
  void showTerminals() {
    if (_activeFile == null) return;
    _activeFile = null;
    notifyListeners();
  }

  // ---- Source control of the current worktree ----

  bool _committed = false;
  bool _pushed = false;
  String? _commitNotice;
  String? get commitNotice => _commitNotice;

  /// Working-tree changes not committed yet.
  List<ChangedFile> get pendingChanges => _committed ? const [] : [for (final f in MockChanges.files) if (!f.committed) f];

  /// Changes already in commits on the branch (vs. origin/main).
  List<ChangedFile> get branchChanges => [
        for (final f in MockChanges.files) if (f.committed) f,
        if (_committed) ...[for (final f in MockChanges.files) if (!f.committed) f],
      ];

  int get commitsAhead => _pushed ? 0 : 2 + (_committed ? 1 : 0);

  /// Optimistic commit; [how] is commit / push / pr / amend.
  bool commit(String message, {String how = 'commit'}) {
    final pending = pendingChanges;
    if (pending.isEmpty || message.trim().isEmpty) return false;
    final n = '${pending.length} ${pending.length == 1 ? 'file' : 'files'}';
    _committed = true;
    _pushed = how == 'push' || how == 'pr';
    _commitNotice = switch (how) {
      'push' => 'Committed $n as 3f9c2ab and pushed',
      'pr' => 'Committed $n, pushed, PR #521 ready for review',
      'amend' => 'Amended 9e41b07 with $n',
      _ => 'Committed $n as 3f9c2ab',
    };
    notifyListeners();
    return true;
  }

  void push() {
    if (!_committed || _pushed) return;
    _pushed = true;
    _commitNotice = 'Pushed to origin/feat/PRC-412-bulk-discounts';
    notifyListeners();
  }

  void undoCommit() {
    _committed = false;
    _pushed = false;
    _commitNotice = null;
    notifyListeners();
  }

  // ---- Terminal commands (⌘D / ⌘⇧D / ⌘W) ----

  /// The Terminal screen registers itself here; the window-level shortcuts
  /// forward to it while the Terminal view is showing.
  void Function(TerminalCommand command)? terminalHandler;

  void sendTerminalCommand(TerminalCommand command) {
    // ⌘T works from any view: it jumps to the Terminal and opens the tab.
    if (command == TerminalCommand.newTerminal && _view != KumoView.terminal) {
      view = KumoView.terminal;
    }
    if (_view == KumoView.terminal) terminalHandler?.call(command);
  }

  @override
  void dispose() {
    workspace
      ..removeListener(_onWorkspaceChanged)
      ..dispose();
    prefs.dispose();
    _undoTimer?.cancel();
    newWorktreeRequests.dispose();
    super.dispose();
  }
}

enum TerminalCommand { splitRight, splitDown, closePane, newTerminal }

enum SidePanelTab {
  files('Files'),
  widgets('Widgets'),
  git('Source control');

  const SidePanelTab(this.label);
  final String label;
}

enum InspectorWidget {
  agent('Agent', 'Ticket, plan steps, review and pause'),
  changes('Changes', 'Uncommitted files; click one to open its diff'),
  context('Context', 'Tickets and docs sent to the agent'),
  tests('Tests', 'Latest gotestsum run for this worktree'),
  pullRequest('Pull request', 'Checks and reviewers of this branch’s PR'),
  activity('Activity', 'What the agent did, as a timeline');

  const InspectorWidget(this.label, this.description);
  final String label;
  final String description;
}

class UndoNotice {
  const UndoNotice(this.message, this.restore);
  final String message;
  final VoidCallback restore;
}

class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope missing');
    return scope!.notifier!;
  }

  /// Read without subscribing (for callbacks).
  static AppState read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    return scope!.notifier!;
  }
}
