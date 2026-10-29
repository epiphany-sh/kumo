import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/agents_source.dart';
import '../data/ci_hosts_source.dart';
import '../data/pipelines_source.dart';
import '../data/docs_source.dart';
import '../data/pull_requests_source.dart';
import '../data/tasks_source.dart';
import '../data/tests_source.dart';
import '../data/changes.dart';
import '../data/workspace_source.dart';
import '../data/worktree_changes.dart';
import '../data/models.dart';
import '../editor/file_buffers.dart';
import '../theme/palette.dart';
import 'preferences.dart';

enum KumoView {
  terminal('Terminal', '⌘1'),
  // The full editor: opened from a file (no side-nav entry; files of the
  // current worktree live in its Files tab).
  files('Files', '', inNav: false),
  agents('Agents', '⌘2'),
  tasks('Tasks', '⌘3'),
  git('Git', '⌘4'),
  docs('Docs', '⌘5');

  const KumoView(this.label, this.shortcut, {this.inNav = true});
  final String label;
  final String shortcut;

  /// Listed in the side-nav (and reachable with ⌘1…⌘5).
  final bool inNav;

  static List<KumoView> get nav => [for (final v in values) if (v.inNav) v];
}

/// Tabs of the current worktree's context, next to its terminal tabs
/// (opened from the icons in the Terminal header).
enum ContextTab {
  files('Files', 'Files of this worktree'),
  git('Git', 'Git of this branch: changes, commits, PR and pipelines');

  const ContextTab(this.label, this.tooltip);
  final String label;
  final String tooltip;
}

/// App-wide UI state. Everything here changes optimistically in the same
/// frame (kumo.md §5.2); once the daemon exists, it confirms or reverts.
class AppState extends ChangeNotifier {
  /// [prefs] restores the user's settings (theme, translucency, side panel)
  /// and keeps them; without it everything is in memory (tests).
  ///
  /// [workspace] provides namespaces, repos and worktrees, and [changesFor]
  /// the git state of the selected worktree (by absolute path): the daemon
  /// in the app, the design mocks when omitted (tests). [pipelinesFor] gives
  /// the CI runs of the selected worktree's branch; without it, the design
  /// mocks ([MockPipelinesSource]) stand in. [ciHosts] keeps the hosts'
  /// tokens (Settings › Repositories).
  AppState({
    KumoThemeMode mode = KumoThemeMode.dark,
    this.demoWallpaper = false,
    Preferences? prefs,
    WorkspaceSource? workspace,
    WorktreeChanges Function(String worktreePath)? changesFor,
    AgentsSource? agents,
    TasksSource? tasks,
    PipelinesFactory? pipelinesFor,
    TestsSource Function(String worktreePath)? testsFor,
    CiHostsSource? ciHosts,
    PullRequestsSource? pullRequests,
    DocsSource? docs,
  })  : prefs = prefs ?? Preferences.memory(),
        workspace = workspace ?? MockWorkspaceSource(),
        agents = agents ?? MockAgentsSource(),
        tasks = tasks ?? MockTasksSource(),
        _changesFor = changesFor,
        _pipelinesFor = pipelinesFor ?? mockPipelinesFor,
        _testsFor = testsFor,
        ciHosts = ciHosts ?? MockCiHostsSource(),
        pullRequests = pullRequests ?? MockPullRequests(),
        docs = docs ?? MockDocsSource(),
        _mode = mode {
    _changes = changesFor == null ? MockWorktreeChanges() : NoWorktreeChanges();
    _changes.addListener(notifyListeners);
    _bindPipelines();
    _bindTests();
    this.workspace.addListener(_onWorkspaceChanged);
    this.agents.addListener(notifyListeners);
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
    _home = false;
    _bindChanges();
    _bindPipelines();
    _bindTests();
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
    _bindChanges();
    _bindPipelines();
    _bindTests();
    notifyListeners();
  }

  /// Opens [path] in the full editor (the Files view, not in the side-nav).
  String? _editRequest;
  void editFile(String path) {
    _editRequest = path;
    _view = KumoView.files;
    notifyListeners();
  }

  /// The file the editor was asked to show, once.
  String? takeEditRequest() {
    final p = _editRequest;
    _editRequest = null;
    return p;
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
    final directory = workspace.absolutePathOf(w);
    if (isActiveWorktree(w)) {
      final main = repo.worktrees.where((w) => w.isMain).firstOrNull;
      activeWorktree = main?.branch ?? 'main';
      activeWorktreePath = main == null || activeWorktreePath == null ? null : main.path;
    }
    _offerUndo(
      'Deleted worktree “$branch”',
      () => _removedWorktrees.remove(key),
      commit: () => workspace.removeWorktree(repo, w).then(
            (_) {
              _removedWorktrees.remove(key);
              _closeWorktreeTerminals(directory);
            },
            // Git refused (e.g. uncommitted changes): show it again.
            onError: (Object _) {
              _removedWorktrees.remove(key);
              notifyListeners();
            },
          ),
    );
  }

  /// The Terminal view registers itself here to close the terminals of a
  /// worktree that was removed.
  void Function(String directory)? terminalSpaceCloser;

  /// Once a worktree is removed from the app: its agents stop and its
  /// terminals close (they'd be left in a folder that no longer exists).
  void _closeWorktreeTerminals(String directory) {
    for (final run in agents.runs) {
      if (run.worktreePath == directory && run.status != AgentStatus.done) agents.stop(run.id).ignore();
    }
    terminalSpaceCloser?.call(directory);
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
  void toggleSidePanel() {
    _sidePanelOpen = !_sidePanelOpen;
    notifyListeners();
  }

  // ---- Context: the selected worktree, or Home ----

  /// Home: plain shells in the home folder that belong to no repository
  /// (Terminal in the side-nav). Selecting a worktree leaves it.
  bool _home = false;
  bool get inHome => _home;

  void showHome() {
    _home = true;
    _view = KumoView.terminal;
    notifyListeners();
  }

  final List<ContextTab> _contextTabs = [];
  ContextTab? _activeContext;

  /// The worktree's Files / Git tabs that are open (none in Home).
  List<ContextTab> get contextTabs => _home ? const [] : List.unmodifiable(_contextTabs);

  /// The context tab showing, or null when terminals or a file tab are.
  ContextTab? get activeContext => _home ? null : _activeContext;

  /// Opens (or goes to) the worktree's [t] tab in the Terminal view.
  void openContext(ContextTab t) {
    _home = false;
    if (!_contextTabs.contains(t)) _contextTabs.add(t);
    _activeContext = t;
    _view = KumoView.terminal;
    notifyListeners();
  }

  void closeContext(ContextTab t) {
    if (!_contextTabs.remove(t)) return;
    if (_activeContext == t) _activeContext = null;
    notifyListeners();
  }

  /// Files open in the Files tab (its tree opens them), in tab order, and
  /// the one showing.
  final List<String> _contextFiles = [];
  String? _contextFile;
  List<String> get contextFiles => List.unmodifiable(_contextFiles);
  String? get contextFile => _contextFile;

  /// Opens [path] in the Files tab (a tab of its own, or the one it has).
  void showContextFile(String path) {
    if (!_contextFiles.contains(path)) _contextFiles.add(path);
    _contextFile = path;
    notifyListeners();
  }

  /// Closes [path]'s tab in the Files tab; its neighbour shows next.
  void closeContextFile(String path) {
    final i = _contextFiles.indexOf(path);
    if (i < 0) return;
    _contextFiles.removeAt(i);
    if (_contextFile == path) _contextFile = _contextFiles.isEmpty ? null : _contextFiles[i > 0 ? i - 1 : 0];
    _forgetBuffer(path);
    notifyListeners();
  }

  /// Keeps only the file showing in the Files tab (and files with unsaved
  /// edits: they never close without asking).
  void closeOtherContextFiles() {
    final keep = [for (final p in _contextFiles) if (p == _contextFile || buffers.isDirty(p)) p];
    final gone = [for (final p in _contextFiles) if (!keep.contains(p)) p];
    _contextFiles
      ..clear()
      ..addAll(keep);
    gone.forEach(_forgetBuffer);
    notifyListeners();
  }

  /// Closes every file in the Files tab but those with unsaved edits.
  void closeAllContextFiles() {
    final keep = [for (final p in _contextFiles) if (buffers.isDirty(p)) p];
    final gone = [for (final p in _contextFiles) if (!keep.contains(p)) p];
    _contextFiles
      ..clear()
      ..addAll(keep);
    gone.forEach(_forgetBuffer);
    if (!keep.contains(_contextFile)) _contextFile = keep.firstOrNull;
    notifyListeners();
  }

  // ---- Editing (the file views) ----

  FileBuffers? _buffers;

  /// Unsaved edits of the current worktree's files.
  FileBuffers get buffers {
    final b = _buffers;
    if (b != null && identical(b.changes, _changes)) return b;
    b
      ?..removeListener(notifyListeners)
      ..dispose();
    return _buffers = FileBuffers(_changes)..addListener(notifyListeners);
  }

  /// A buffer goes once no tab shows its file.
  void _forgetBuffer(String path) {
    if (_contextFiles.contains(path) || _openFiles.contains(path)) return;
    buffers.forget(path);
  }

  /// A tab with unsaved edits that asked to close: its file view asks
  /// whether to save them. `$2` is true for the Files tab's tabs.
  (String, bool)? _closeAsk;
  (String, bool)? get closeAsk => _closeAsk;

  /// Closes [path]'s tab ([files]: in the Files tab, else a file tab of the
  /// Terminal view); with unsaved edits, shows the file and asks first.
  void askClose(String path, {bool files = false}) {
    if (!buffers.isDirty(path)) {
      files ? closeContextFile(path) : closeFile(path);
      return;
    }
    files ? showContextFile(path) : openFile(path);
    _closeAsk = (path, files);
    notifyListeners();
  }

  /// The answer to [closeAsk]: save (or drop) the edits, then close. Returns
  /// why saving failed (the tab stays), or null.
  Future<String?> answerClose({required bool save}) async {
    final ask = _closeAsk;
    if (ask == null) return null;
    _closeAsk = null;
    final (path, files) = ask;
    if (save) {
      final error = await buffers.save(path);
      if (error != null) {
        notifyListeners();
        return error;
      }
    } else {
      buffers.revert(path);
    }
    files ? closeContextFile(path) : closeFile(path);
    return null;
  }

  void cancelClose() {
    if (_closeAsk == null) return;
    _closeAsk = null;
    notifyListeners();
  }

  // ---- Files and folders (the Files tree's menus) ----

  /// Deleted files and folders still within the undo window: hidden until
  /// the window closes, then deleted.
  final Set<String> _deleting = {};

  /// [path] is, or is inside, something being deleted.
  bool isDeleting(String path) => _deleting.any((d) => path == d || path.startsWith('$d/'));

  /// The worktree's files, minus those being deleted.
  List<String> get visibleFiles => _deleting.isEmpty ? _changes.files : [for (final f in _changes.files) if (!isDeleting(f)) f];

  static String cleanPath(String raw) => raw.trim().replaceAll(RegExp(r'^/+|/+$'), '').replaceAll(RegExp(r'/+'), '/');

  /// Something is at [path]: a file, or a folder with files in it.
  bool pathExists(String path) => _changes.files.any((f) => f == path || f.startsWith('$path/'));

  /// A new empty file (its folders are created). Returns why not, or null.
  Future<String?> createFile(String raw) async {
    final path = cleanPath(raw);
    if (path.isEmpty || path.endsWith('.')) return 'Give the file a name';
    if (pathExists(path)) return '$path already exists';
    final changes = _changes;
    await changes.write(path, '');
    if (!identical(changes, _changes)) return null;
    return changes.error;
  }

  /// Renames or moves a file or folder; its tabs and unsaved edits follow.
  /// Returns why not, or null.
  Future<String?> movePath(String from, String raw) async {
    final to = cleanPath(raw);
    if (to.isEmpty) return 'Give it a name';
    if (to == from) return null;
    if (to.startsWith('$from/')) return 'A folder can’t go inside itself';
    // Exact case: on a case-insensitive disk `Foo.go` → `foo.go` is a rename.
    if (pathExists(to)) return '$to already exists';
    final changes = _changes;
    final ok = await changes.move(from, to);
    if (_disposed || !identical(changes, _changes)) return null;
    if (!ok) return changes.error ?? 'Couldn’t rename ${from.split('/').last}';
    String follow(String p) => p == from ? to : (p.startsWith('$from/') ? to + p.substring(from.length) : p);
    for (final list in [_contextFiles, _openFiles]) {
      for (var i = 0; i < list.length; i++) {
        list[i] = follow(list[i]);
      }
    }
    if (_contextFile != null) _contextFile = follow(_contextFile!);
    if (_activeFile != null) _activeFile = follow(_activeFile!);
    buffers.moved(from, to);
    notifyListeners();
    return null;
  }

  /// Deletes a file, or a folder with everything in it. It leaves the tree
  /// and its tabs close at once; the disk changes when the undo window
  /// closes (Undo brings it all back).
  void deletePath(String path) {
    if (isDeleting(path)) return;
    bool inside(String p) => p == path || p.startsWith('$path/');
    final ctxBefore = List.of(_contextFiles);
    final ctxFileBefore = _contextFile;
    final openBefore = List.of(_openFiles);
    final activeBefore = _activeFile;
    // Buffers (unsaved edits included) stay until the deletion happens, so
    // Undo brings the edits back with the tabs.
    final closed = {..._contextFiles.where(inside), ..._openFiles.where(inside)};
    _contextFiles.removeWhere(inside);
    _openFiles.removeWhere(inside);
    if (_contextFile != null && inside(_contextFile!)) _contextFile = _contextFiles.lastOrNull;
    if (_activeFile != null && inside(_activeFile!)) _activeFile = _openFiles.lastOrNull;
    _deleting.add(path);
    final changes = _changes;
    _offerUndo(
      'Deleted ${path.split('/').last}',
      () {
        _deleting.remove(path);
        if (!identical(changes, _changes)) return;
        _contextFiles
          ..clear()
          ..addAll(ctxBefore);
        _contextFile = ctxFileBefore;
        _openFiles
          ..clear()
          ..addAll(openBefore);
        _activeFile = activeBefore;
      },
      commit: () {
        if (identical(changes, _changes)) closed.forEach(_forgetBuffer);
        changes.remove([path]).whenComplete(() {
          if (_disposed || !identical(changes, _changes)) return;
          _deleting.remove(path);
          notifyListeners();
        });
      },
    );
  }

  /// Takes every changed file inside [dir] back to the last commit (files
  /// git doesn't track yet are deleted), with an undo window like
  /// [discardChanges].
  void discardChangesIn(String dir) {
    final paths = [for (final f in pendingChanges) if (f.path.startsWith('$dir/')) f.path];
    if (paths.isEmpty) return;
    _discarding.addAll(paths);
    final changes = _changes;
    _offerUndo(
      'Discarded ${paths.length} ${paths.length == 1 ? 'change' : 'changes'} in ${dir.split('/').last}',
      () => _discarding.removeAll(paths),
      commit: () => _discarded = changes.restoreAll(paths).whenComplete(() {
        if (_disposed || !identical(changes, _changes)) return;
        _discarding.removeAll(paths);
        notifyListeners();
      }),
    );
  }

  // ---- Inspector widgets (the Widgets tab) ----

  List<InspectorWidget> _widgets = const [InspectorWidget.agent, InspectorWidget.pipelines, InspectorWidget.changes, InspectorWidget.context];
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
  /// File tabs belong to the worktree's context: none in Home.
  List<String> get openFiles => _home ? const [] : List.unmodifiable(_openFiles);
  String? _activeFile;

  /// The file tab showing, or null when the terminal panes (or a context
  /// tab) are showing.
  String? get activeFile => _home || activeContext != null ? null : _activeFile;

  void openFile(String path) {
    if (!_openFiles.contains(path)) _openFiles.add(path);
    _activeFile = path;
    _activeContext = null;
    _home = false;
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
    _activeContext = null;
    _home = false;
    _view = KumoView.terminal;
    notifyListeners();
  }

  void closeFile(String path) {
    final i = _openFiles.indexOf(path);
    if (i < 0) return;
    _openFiles.removeAt(i);
    if (_activeFile == path) _activeFile = _openFiles.isEmpty ? null : _openFiles[i > 0 ? i - 1 : 0];
    _forgetBuffer(path);
    notifyListeners();
  }

  /// Back to the terminal panes (a terminal tab was clicked).
  void showTerminals() {
    if (_activeFile == null && _activeContext == null) return;
    _activeFile = null;
    _activeContext = null;
    notifyListeners();
  }

  // ---- Source control of the current worktree ----

  final WorktreeChanges Function(String worktreePath)? _changesFor;
  late WorktreeChanges _changes;
  String? _changesPath;

  /// Git and files of the selected worktree.
  WorktreeChanges get changes => _changes;

  /// Follows the selection: a new [WorktreeChanges] per worktree.
  void _bindChanges() {
    final factory = _changesFor;
    if (factory == null) return;
    final entry = activeWorktreeEntry;
    final path = entry == null ? null : workspace.absolutePathOf(entry);
    if (path == _changesPath) return;
    // A discard still in its undo window happens now, on its own worktree.
    if (_discarding.isNotEmpty || _deleting.isNotEmpty) dismissUndo();
    _discarding.clear();
    _deleting.clear();
    _closeAsk = null;
    // Unsaved edits are saved before leaving their worktree, never lost.
    _buffers
      ?..saveAll()
      ..removeListener(notifyListeners)
      ..dispose();
    _buffers = null;
    _changes
      ..removeListener(notifyListeners)
      ..dispose();
    _changesPath = path;
    _changes = path == null ? NoWorktreeChanges() : factory(path);
    _changes.addListener(notifyListeners);
    // Another worktree: its own files.
    _contextFiles.clear();
    _contextFile = null;
    _commitNotice = null;
    _canUndoCommit = false;
  }

  /// What the last commit, push, pull or fetch did (or is doing).
  String? _commitNotice;
  String? get commitNotice => _commitNotice;

  /// Whether [commitNotice] is about a commit that can still be undone
  /// (not once it was pushed).
  bool _canUndoCommit = false;
  bool get canUndoCommit => _canUndoCommit;

  /// Git answers asynchronously; ignore answers that arrive after disposal.
  bool _disposed = false;

  /// Working-tree changes not committed yet (minus the ones being
  /// discarded).
  List<ChangedFile> get pendingChanges => [for (final f in _changes.pending) if (!_discarding.contains(f.path)) f];

  /// Files whose changes are being discarded, still within the undo window.
  final Set<String> _discarding = {};
  bool isDiscarding(String path) => _discarding.contains(path);

  /// Takes [path] back to the last commit (a file git doesn't track yet is
  /// deleted). It disappears from the changes at once; git does it when the
  /// undo window closes.
  void discardChanges(String path) {
    if (!_discarding.add(path)) return;
    final changes = _changes;
    _offerUndo(
      'Discarded changes to ${path.split('/').last}',
      () => _discarding.remove(path),
      commit: () => _discarded = changes.restore(path).whenComplete(() {
        if (_disposed || !identical(changes, _changes)) return;
        _discarding.remove(path);
        notifyListeners();
      }),
    );
  }

  Future<void>? _discarded;

  /// Discards still in their undo window happen now; done when git did.
  Future<void> _settleDiscards() {
    if (_discarding.isEmpty) return Future.value();
    dismissUndo();
    return _discarded ?? Future.value();
  }

  /// Changes already in commits on the branch (vs. its base).
  List<ChangedFile> get branchChanges => _changes.onBranch;

  int get commitsAhead => _changes.ahead;

  /// A changed file of this worktree, uncommitted or on the branch.
  ChangedFile? changedFile(String path) => [...pendingChanges, ...branchChanges].where((f) => f.path == path).firstOrNull;

  /// Commits every change ([all]) or the staged ones; [how] is commit /
  /// push / amend. Returns false when there is nothing to commit or no
  /// message. Optimistic: the notice shows at once and gets the sha (or the
  /// error) when git answers.
  bool commit(String message, {String how = 'commit', bool all = true}) {
    final count = all ? pendingChanges.length : _changes.stagedList.length;
    if (count == 0 || message.trim().isEmpty) return false;
    final n = '$count ${count == 1 ? 'file' : 'files'}';
    final push = how == 'push';
    _commitNotice = how == 'amend' ? 'Amending with $n…' : 'Committed $n${push ? ', pushing…' : ''}';
    _canUndoCommit = false;
    final changes = _changes;
    // A file being discarded must not end up in the commit.
    Future<String?> run() => changes.commit(message, all: all, amend: how == 'amend', push: push);
    final committing = _discarding.isEmpty ? run() : _settleDiscards().then((_) => run());
    notifyListeners();
    committing.then((sha) {
      if (_disposed || !identical(changes, _changes)) return;
      _canUndoCommit = sha != null && !push;
      _commitNotice = sha == null
          ? 'Commit failed: ${changes.error ?? 'unknown error'}'
          : switch (how) {
              'push' => 'Committed $n as $sha and pushed',
              'amend' => 'Amended $sha with $n',
              _ => 'Committed $n as $sha · not pushed yet',
            };
      notifyListeners();
    });
    return true;
  }

  /// Whether there is something to push: commits ahead, or a branch that
  /// was never pushed.
  bool get canPush => _changes.branch.isNotEmpty && (_changes.ahead > 0 || !_changes.pushed);

  void push() {
    if (!canPush) return;
    final changes = _changes;
    final pipelines = _pipelines;
    Future<void> run() => changes.push().then((_) {
          // A first push starts the branch's pipelines.
          if (changes.error == null && identical(pipelines, _pipelines)) pipelines.branchPushed();
        });
    _sync('Pushing…', run, (c) => 'Pushed ${c.branch}', 'Push');
  }

  void pull() => _sync('Pulling…', _changes.pull, (c) => 'Pulled into ${c.branch}', 'Pull');

  void fetch() => _sync('Fetching…', _changes.fetch, (_) => 'Fetched', 'Fetch');

  /// Runs a remote git action with its notice: [doing] now, then [done] or
  /// why [what] failed.
  void _sync(String doing, Future<void> Function() run, String Function(WorktreeChanges changes) done, String what) {
    final changes = _changes;
    _commitNotice = doing;
    _canUndoCommit = false;
    notifyListeners();
    run().then((_) {
      if (_disposed || !identical(changes, _changes)) return;
      final error = changes.error;
      _commitNotice = error == null ? done(changes) : '$what failed: $error';
      notifyListeners();
    });
  }

  void undoCommit() {
    _commitNotice = null;
    _canUndoCommit = false;
    _changes.undoLastCommit();
    notifyListeners();
  }

  // ---- Pipelines of the current worktree ----

  final PipelinesFactory _pipelinesFor;
  PipelinesSource _pipelines = NoPipelines();
  String? _pipelinesKey;

  /// CI runs of the selected worktree's branch (the Pipelines widget).
  PipelinesSource get pipelines => _pipelines;

  /// The repository hosts' tokens, for pipelines.
  final CiHostsSource ciHosts;

  /// Pull requests of the repositories' hosts (same tokens as pipelines).
  final PullRequestsSource pullRequests;

  /// Confluence and Obsidian pages, through the task sources.
  final DocsSource docs;

  /// Follows the selection: one [PipelinesSource] per worktree.
  void _bindPipelines() {
    final repo = activeRepo;
    final entry = activeWorktreeEntry;
    final path = entry == null ? null : workspace.absolutePathOf(entry);
    final key = repo == null || entry == null ? null : '${repo.id}|${entry.branch}|${path ?? ''}';
    if (key == _pipelinesKey) return;
    _pipelinesKey = key;
    _pipelines
      ..removeListener(notifyListeners)
      ..dispose();
    _pipelines = repo == null || entry == null ? NoPipelines() : _pipelinesFor(repo: repo, worktree: entry, worktreePath: path ?? '');
    _pipelines.addListener(notifyListeners);
  }

  // ---- Tests ----

  final TestsSource Function(String worktreePath)? _testsFor;
  TestsSource _tests = NoTests();
  String? _testsPath;

  /// Tests of the selected worktree: its command and latest run.
  TestsSource get tests => _tests;

  /// Follows the selection: one [TestsSource] per worktree.
  void _bindTests() {
    final entry = activeWorktreeEntry;
    final path = entry == null ? null : workspace.absolutePathOf(entry);
    if (path == _testsPath) return;
    _testsPath = path;
    _tests
      ..removeListener(notifyListeners)
      ..dispose();
    final factory = _testsFor;
    _tests = path == null || factory == null ? NoTests() : factory(path);
    _tests.addListener(notifyListeners);
  }

  /// The test command the user typed for the selected repository (empty:
  /// the detected one).
  String get testCommand => activeRepo == null ? '' : setting<String>('tests.command.${activeRepo!.id}', '');
  set testCommand(String command) {
    final repo = activeRepo;
    if (repo != null) setSetting('tests.command.${repo.id}', command.trim().isEmpty ? null : command.trim());
  }

  // ---- Agents ----

  /// Coding agents (optional): connected providers and running sessions.
  final AgentsSource agents;

  /// The Terminal view registers itself here to open daemon terminals
  /// (agents, sign-in flows) in a pane.
  void Function(String terminalId, String title, {bool agent, String? directory})? terminalOpener;

  /// Shows [terminalId] in a pane of the Terminal view: with the terminals
  /// of the worktree at [directory], else with the current ones.
  void openTerminal(String terminalId, {required String title, bool agent = false, String? directory}) {
    view = KumoView.terminal;
    terminalOpener?.call(terminalId, title, agent: agent, directory: directory);
  }

  /// Goes to work in [worktree]: selects it and shows its terminals (the
  /// Terminal view opens a shell in it the first time).
  void openWorktree(Worktree worktree) {
    selectWorktree(worktree.branch, path: worktree.path);
    view = KumoView.terminal;
    showTerminals();
  }

  // ---- Tasks ----

  /// Tasks from the user's tools. Views listen to it directly: a board
  /// update doesn't rebuild the rest of the app.
  final TasksSource tasks;

  /// Starts work on [task]: a new worktree on [branch], linked to the task,
  /// the task moved to In progress where its tool allows, and (with
  /// [agent]) an agent with the task as its prompt. Throws a readable
  /// message if the worktree can't be created; returns why the agent
  /// didn't start, or null.
  Future<String?> startTask(TaskEntry task, {required Repo repo, required String branch, String base = '', String path = '', bool agent = true, String? providerId}) async {
    try {
      await workspace.createWorktree(repo, branch: branch, createBranch: true, base: base, path: path);
    } on Object catch (e) {
      throw workspace.error ?? '$e';
    }
    final created = workspace.repo(repo.id)?.worktrees.where((w) => w.branch == branch).firstOrNull;
    final worktreePath = created == null ? '' : workspace.absolutePathOf(created);
    if (created != null) openWorktree(created);
    await tasks.link(task.id, worktreePath: worktreePath.isEmpty ? path : worktreePath, branch: branch);
    final source = tasks.source(task.sourceId);
    if (task.column == TaskColumn.todo && (source?.writable.contains(TaskColumn.doing) ?? false)) {
      tasks.setStatus(task.id, TaskColumn.doing).ignore();
    }
    if (!agent || created == null || !agents.live || agents.connected.isEmpty) return null;
    // The whole ticket when it can be had (cached, else asked for); the
    // card's fields when the source can't answer.
    var detail = tasks.cachedDetail(task.id);
    if (detail == null) {
      try {
        detail = await tasks.getTask(task.id).timeout(const Duration(seconds: 10));
      } on Object {
        detail = null;
      }
    }
    final run = await agents.start(
      providerId: providerId,
      worktreePath: worktreePath,
      prompt: taskPrompt(task, detail: detail),
      title: '${task.key} · ${task.title}',
      context: [taskContext(task)],
    );
    if (run == null) return 'Worktree ready, but the agent didn’t start: ${agents.error ?? 'unknown error'}';
    openTerminal(run.terminalId, title: run.title, agent: true, directory: worktreePath);
    return null;
  }

  /// Agents of the selected worktree, newest first.
  List<AgentRun> get worktreeAgents {
    final entry = activeWorktreeEntry;
    if (entry == null) return const [];
    final path = workspace.absolutePathOf(entry);
    return [for (final r in agents.runs) if (r.worktreePath == path) r]..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  }

  /// Tasks linked to the selected worktree.
  List<TaskEntry> get worktreeTasks {
    final entry = activeWorktreeEntry;
    if (entry == null) return const [];
    final path = workspace.absolutePathOf(entry);
    final ids = {for (final l in tasks.links) if (l.worktreePath == path) l.taskId};
    return [for (final t in tasks.tasks) if (ids.contains(t.id)) t];
  }

  /// The selected worktree's agent that is still running (the newest).
  AgentRun? get activeAgent => worktreeAgents.where((r) => r.status != AgentStatus.done).firstOrNull;

  /// [task] as an agent's context: key and title, and where it lives.
  AgentContextItem taskContext(TaskEntry task) => AgentContextItem(
        kind: AgentContextKind.task,
        title: '${task.key} · ${task.title}',
        detail: [tasks.source(task.sourceId)?.kind.label ?? '', task.typeName].where((p) => p.isNotEmpty).join(' · '),
        url: task.url,
      );

  /// What an agent gets when it starts from a task: title, key and source,
  /// and with the [detail] its description, acceptance criteria (its
  /// definition of done) and comments. Attachments, subtasks and links
  /// stay out; the link goes in so the agent can look them up.
  static String taskPrompt(TaskEntry task, {TaskDetail? detail}) {
    final t = detail == null || detail.task.id != task.id ? task : detail.task;
    final where = [t.kind.label, if (t.context.isNotEmpty) t.context].join(' · ');
    final status = t.sourceStatus.isNotEmpty ? t.sourceStatus : '';
    final d = detail;
    return [
      t.title,
      '',
      'Task ${t.key} ($where).',
      if (status.isNotEmpty) 'Status: $status.',
      if (t.labels.isNotEmpty) 'Labels: ${t.labels.join(', ')}.',
      if (t.due.isNotEmpty) 'Due ${t.due}.',
      if (t.url.startsWith('http')) t.url,
      if (d != null && d.description.trim().isNotEmpty) ...['', '## Description', '', d.description.trim()],
      if (d != null && d.acceptanceCriteria.trim().isNotEmpty) ...[
        '',
        '## Acceptance criteria',
        '',
        'This is the definition of done.',
        '',
        d.acceptanceCriteria.trim(),
      ],
      if (d != null && d.comments.isNotEmpty) ...[
        '',
        '## Comments',
        for (final c in d.comments) ...[
          '',
          '${c.author.name}${c.author.you ? ' (the user)' : ''}${c.created == null ? '' : ', ${c.created!.toIso8601String().substring(0, 10)}'}:',
          c.body.trim(),
        ],
      ],
    ].join('\n');
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
    _disposed = true;
    agents
      ..removeListener(notifyListeners)
      ..dispose();
    tasks.dispose();
    _buffers
      ?..removeListener(notifyListeners)
      ..dispose();
    _changes
      ..removeListener(notifyListeners)
      ..dispose();
    _pipelines
      ..removeListener(notifyListeners)
      ..dispose();
    _tests
      ..removeListener(notifyListeners)
      ..dispose();
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

enum InspectorWidget {
  agent('Agent', 'What this worktree’s agent is doing, its diff and terminal'),
  changes('Changes', 'Uncommitted files; click one to open its diff'),
  context('Context', 'Tickets and pages the agent works from'),
  pipelines('Pipelines', 'CI runs of this branch on GitHub, GitLab or Bitbucket'),
  tests('Tests', 'Runs this worktree’s tests and reads the results'),
  pullRequest('Pull request', 'Checks and reviewers of this branch’s PR'),
  activity('Activity', 'What agents and tests did, as a timeline');

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

/// Builds the [PipelinesSource] of a worktree: [worktreePath] is absolute
/// (empty for mocks).
typedef PipelinesFactory = PipelinesSource Function({required Repo repo, required Worktree worktree, required String worktreePath});

/// The design mocks, per worktree: a running pipeline, or "no pipelines
/// yet" for a branch that was never pushed.
PipelinesSource mockPipelinesFor({required Repo repo, required Worktree worktree, required String worktreePath}) {
  final provider = CiProvider.ofHost(repo.host);
  return MockPipelinesSource(
    provider: provider,
    repo: repo.name,
    branch: worktree.branch,
    scenario: worktree.everPushed ? MockPipelinesScenario.running : MockPipelinesScenario.notPushed,
    unpushed: worktree.unpushed,
  );
}
