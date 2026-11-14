import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/app/kumo_app.dart';
import 'package:kumo_ui/data/agents_source.dart';
import 'package:kumo_ui/data/models.dart';
import 'package:kumo_ui/data/pull_requests_source.dart';
import 'package:kumo_ui/data/shell_activity_source.dart';
import 'package:kumo_ui/data/worktree_lights.dart';
import 'package:kumo_ui/shell/sidebar.dart';
import 'package:kumo_ui/widgets/kicons.dart';

const _a = '/wt/repo-1/a';
const _b = '/wt/repo-1/b';

AgentRun _run(String id, String at, AgentStatus status, {int exit = 0, bool asked = false}) => AgentRun(
      id: id,
      providerId: 'claude',
      providerName: 'Claude Code',
      short: 'CC',
      worktreePath: at,
      terminalId: 't-$id',
      title: id,
      status: status,
      startedAt: DateTime(2026),
      exitCode: exit,
      asked: asked,
    );

class _Agents extends MockAgentsSource {
  List<AgentRun> current = const [];
  @override
  List<AgentRun> get runs => current;
  @override
  List<TerminalAgent> get terminalAgents => const [];

  void set(List<AgentRun> runs) {
    current = runs;
    notifyListeners();
  }
}

class _Shells extends ShellActivitySource {
  List<ShellActivity> current = const [];
  bool _loaded = false;
  @override
  List<ShellActivity> get shells => current;
  @override
  bool get loaded => _loaded;

  void set(List<ShellActivity> shells) {
    current = shells;
    _loaded = true;
    notifyListeners();
  }
}

class _Prs extends MockPullRequests {
  @override
  Future<BranchPullRequest> forBranch(String worktreePath, {bool refresh = false}) async => BranchPullRequest(
        pullRequest: worktreePath.endsWith('TSK-412')
            ? const PullRequestInfo(number: 521, label: '#521', title: 'bulk discounts', author: 'someone', branch: 'feat/TSK-412-bulk-discounts', state: PrOpenState.merged)
            : null,
      );
}

void main() {
  group('WorktreeLights', () {
    late WorktreeLights lights;
    void read(List<AgentRun> runs, {List<TerminalAgent> hand = const [], List<ShellActivity>? shells, String? looking}) => lights.update(
          runs: runs,
          handTyped: hand,
          shells: shells ?? const [],
          shellsLoaded: shells != null,
          worktrees: const [_a, _b, '$_a/nested'],
          looking: looking,
        );
    WorktreeLight light(String path) => lights.of(path, DateTime(2026, 1, 1, 10)).light;
    String why(String path, [DateTime? now]) => lights.of(path, now ?? DateTime(2026, 1, 1, 10)).why;

    setUp(() => lights = WorktreeLights());

    test('what ended before Kumo opened isn’t news', () {
      read([_run('1', _a, AgentStatus.done), _run('2', _b, AgentStatus.done, exit: 1)]);
      expect(light(_a), WorktreeLight.idle);
      expect(light(_b), WorktreeLight.idle);
    });

    test('working, then quiet: done until you look', () {
      read([_run('1', _a, AgentStatus.running)]);
      expect(light(_a), WorktreeLight.working);
      read([_run('1', _a, AgentStatus.needsYou)]);
      expect(light(_a), WorktreeLight.done, reason: 'its turn ended');
      read([_run('1', _a, AgentStatus.needsYou)]);
      expect(light(_a), WorktreeLight.done, reason: 'news stay');
      lights.seen(_a);
      expect(light(_a), WorktreeLight.idle);
    });

    test('asking outranks working; a failure outranks both; Stop isn’t a failure', () {
      read([_run('1', _a, AgentStatus.running), _run('2', _a, AgentStatus.running), _run('3', _b, AgentStatus.running)]);
      read([_run('1', _a, AgentStatus.needsYou, asked: true), _run('2', _a, AgentStatus.running), _run('3', _b, AgentStatus.done, exit: 143)]);
      expect(light(_a), WorktreeLight.asking);
      expect(light(_b), WorktreeLight.idle, reason: 'stopped by you');
      read([_run('1', _a, AgentStatus.needsYou, asked: true), _run('2', _a, AgentStatus.done, exit: 2)]);
      expect(light(_a), WorktreeLight.failed);
      expect(why(_a), 'Claude Code failed');
    });

    test('a run that fails before it was seen working is news too', () {
      read(const []);
      read([_run('1', _a, AgentStatus.done, exit: 127)]);
      expect(light(_a), WorktreeLight.failed);
    });

    test('no news for the worktree on screen', () {
      read([_run('1', _a, AgentStatus.running)]);
      read([_run('1', _a, AgentStatus.done)], looking: _a);
      expect(light(_a), WorktreeLight.idle);
    });

    test('an agent typed in a terminal counts where its folder is: the deepest worktree', () {
      read(const [], hand: const [TerminalAgent(terminalId: 'z', providerId: 'claude', name: 'claude', terminalTitle: 'zsh', cwd: '$_a/nested/src', busy: true)]);
      expect(light('$_a/nested'), WorktreeLight.working);
      expect(light(_a), WorktreeLight.idle);
    });
  });

  group('WorktreeLights, shells', () {
    late WorktreeLights lights;
    final ten = DateTime(2026, 1, 1, 10);
    void read(List<ShellActivity> shells, {bool loaded = true, List<TerminalAgent> hand = const [], String? looking}) =>
        lights.update(runs: const [], handTyped: hand, shells: shells, shellsLoaded: loaded, worktrees: const [_a, _b], looking: looking);
    ShellActivity shell(String id, String cwd, {RunningCommand? running, FinishedCommand? last}) =>
        ShellActivity(terminalId: id, cwd: cwd, running: running, last: last);
    FinishedCommand ended(String command, int? exit, int minute) => FinishedCommand(command: command, exit: exit, at: ten.add(Duration(minutes: minute)));

    setUp(() => lights = WorktreeLights());

    test('what the shells had finished by the first answer isn’t news', () {
      read(const [], loaded: false);
      read([shell('1', '$_a/src', last: ended('make', 2, 0))]);
      expect(lights.of(_a, ten).light, WorktreeLight.idle);
      read([shell('1', '$_a/src', last: ended('make', 2, 0))]);
      expect(lights.of(_a, ten).light, WorktreeLight.idle, reason: 'the same command again isn’t new');
    });

    test('a command that fails lights red; one that works, green; Ctrl-C, nothing', () {
      read([shell('1', _a), shell('2', _b), shell('3', _b)]);
      read([
        shell('1', _a, last: ended('cargo test --workspace', 101, 1)),
        shell('2', _b, last: ended('npm run dev', 130, 1)),
      ]);
      expect(lights.of(_a, ten), const WorktreeSignal(WorktreeLight.failed, 'cargo test --workspace failed (exit 101)'));
      expect(lights.of(_b, ten).light, WorktreeLight.idle, reason: 'stopped by you');
      read([shell('3', _b, last: ended('', 0, 2))]);
      expect(lights.of(_b, ten), const WorktreeSignal(WorktreeLight.done, 'A command finished'));
      lights.seen(_a);
      expect(lights.of(_a, ten).light, WorktreeLight.idle);
    });

    test('a command running pulses, then turns into a server; an agent’s shell is the agent', () {
      final started = RunningCommand(command: 'npm run dev', since: ten);
      read([shell('1', _a, running: started), shell('2', _b, running: RunningCommand(command: 'claude', since: ten))],
          hand: const [TerminalAgent(terminalId: '2', providerId: 'claude', name: 'claude', terminalTitle: 'zsh', cwd: _b)]);
      expect(lights.of(_a, ten.add(const Duration(minutes: 1))), const WorktreeSignal(WorktreeLight.working, 'npm run dev is running'));
      expect(lights.nextChange(ten.add(const Duration(minutes: 1))), ten.add(WorktreeLights.servingAfter));
      expect(lights.of(_a, ten.add(const Duration(minutes: 72))), const WorktreeSignal(WorktreeLight.serving, 'npm run dev has been running for 1 h 12 min'));
      expect(lights.nextChange(ten.add(const Duration(minutes: 72))), isNull);
      expect(lights.of(_b, ten).light, WorktreeLight.idle, reason: 'claude is quiet: not a command running');
    });

    test('no news from the shells of the worktree on screen', () {
      read([shell('1', _a)]);
      read([shell('1', _a, last: ended('false', 1, 1))], looking: _a);
      expect(lights.of(_a, ten).light, WorktreeLight.idle);
    });
  });

  test('AppState: an agent finishing elsewhere lights its worktree until you open it', () {
    final agents = _Agents();
    final s = AppState(agents: agents);
    final repo = s.workspace.repos.first;
    final other = repo.worktrees.firstWhere((w) => !s.isActiveWorktree(w));
    expect(s.worktreeLight(other).signal.light, isNot(WorktreeLight.failed));

    agents.set([_run('1', other.path, AgentStatus.running)]);
    expect(s.worktreeLight(other), (signal: const WorktreeSignal(WorktreeLight.working, 'Claude Code is working'), pulse: true));
    agents.set([_run('1', other.path, AgentStatus.done, exit: 1)]);
    expect(s.worktreeLight(other), (signal: const WorktreeSignal(WorktreeLight.failed, 'Claude Code failed'), pulse: false));

    s.selectWorktree(other.branch, path: other.path);
    expect(s.worktreeLight(other).signal.light, isNot(WorktreeLight.failed), reason: 'seen');
    s.dispose();
  });

  test('AppState: a command elsewhere pulses while it runs, then its failure stays until you look', () {
    final shells = _Shells();
    final s = AppState(shells: shells);
    final other = s.workspace.repos.first.worktrees.firstWhere((w) => !s.isActiveWorktree(w));
    shells.set(const []);

    shells.set([ShellActivity(terminalId: 't', cwd: other.path, running: RunningCommand(command: 'make', since: DateTime.now()))]);
    expect(s.worktreeLight(other), (signal: const WorktreeSignal(WorktreeLight.working, 'make is running'), pulse: true));
    shells.set([ShellActivity(terminalId: 't', cwd: other.path, last: FinishedCommand(command: 'make', exit: 2, at: DateTime.now()))]);
    expect(s.worktreeLight(other).signal, const WorktreeSignal(WorktreeLight.failed, 'make failed (exit 2)'));
    s.selectWorktree(other.branch, path: other.path);
    expect(s.worktreeLight(other).signal.light, isNot(WorktreeLight.failed));
    s.dispose();
  });

  testWidgets('a merged branch shows the merge mark next to its worktree', (tester) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState(demoWallpaper: true, pullRequests: _Prs());
    await tester.pumpWidget(KumoApp(state: state));
    await tester.pump();
    await tester.pump();
    final mark = find.byTooltip('#521 merged: this worktree can go');
    expect(mark, findsOneWidget);
    final icon = tester.widget<Icon>(find.descendant(of: mark, matching: find.byType(Icon)));
    expect(icon.icon, KIcons.merged);
    expect(find.byType(WorktreeDot), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
