import 'dart:async';

import 'package:flutter/widgets.dart';

import '../data/agents_source.dart';
import '../data/ci_hosts_source.dart';
import '../data/pipelines_source.dart';
import '../data/tasks_source.dart';
import '../data/changes.dart';
import '../data/workspace_source.dart';
import '../data/worktree_changes.dart';
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
    CiHostsSource? ciHosts,
  })  : prefs = prefs ?? Preferences.memory(),
        workspace = workspace ?? MockWorkspaceSource(),
        agents = agents ?? MockAgentsSource(),
        tasks = tasks ?? MockTasksSource(),
        _changesFor = changesFor,
        _pipelinesFor = pipelinesFor ?? mockPipelinesFor,
        ciHosts = ciHosts ?? MockCiHostsSource(),
        _mode = mode {
    _changes = changesFor == null ? MockWorktreeChanges() : NoWorktreeChanges();
    _changes.addListener(notifyListeners);
    _bindPipelines();
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
    _bindChanges();
    _bindPipelines();
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
    if (_discarding.isNotEmpty) dismissUndo();
    _discarding.clear();
    _changes
      ..removeListener(notifyListeners)
      ..dispose();
    _changesPath = path;
    _changes = path == null ? NoWorktreeChanges() : factory(path);
    _changes.addListener(notifyListeners);
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
    final run = await agents.start(providerId: providerId, worktreePath: worktreePath, prompt: taskPrompt(task, detail: detail), title: '${task.key} · ${task.title}');
    if (run == null) return 'Worktree ready, but the agent didn’t start: ${agents.error ?? 'unknown error'}';
    openTerminal(run.terminalId, title: run.title, agent: true, directory: worktreePath);
    return null;
  }

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
    _changes
      ..removeListener(notifyListeners)
      ..dispose();
    _pipelines
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
  pipelines('Pipelines', 'CI runs of this branch on GitHub, GitLab or Bitbucket'),
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
