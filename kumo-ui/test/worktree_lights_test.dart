import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/app/kumo_app.dart';
import 'package:kumo_ui/data/agents_source.dart';
import 'package:kumo_ui/data/models.dart';
import 'package:kumo_ui/data/pull_requests_source.dart';
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

class _Prs extends MockPullRequests {
  @override
  Future<BranchPullRequest> forBranch(String worktreePath, {bool refresh = false}) async => BranchPullRequest(
        pullRequest: worktreePath.endsWith('PRC-412')
            ? const PullRequestInfo(number: 521, label: '#521', title: 'bulk discounts', author: 'someone', branch: 'feat/PRC-412-bulk-discounts', state: PrOpenState.merged)
            : null,
      );
}

void main() {
  group('WorktreeLights', () {
    late WorktreeLights lights;
    void read(List<AgentRun> runs, {List<TerminalAgent> hand = const [], String? looking}) =>
        lights.update(runs: runs, handTyped: hand, worktrees: const [_a, _b, '$_a/nested'], looking: looking);

    setUp(() => lights = WorktreeLights());

    test('what ended before Kumo opened isn’t news', () {
      read([_run('1', _a, AgentStatus.done), _run('2', _b, AgentStatus.done, exit: 1)]);
      expect(lights.of(_a), WorktreeLight.idle);
      expect(lights.of(_b), WorktreeLight.idle);
    });

    test('working, then quiet: done until you look', () {
      read([_run('1', _a, AgentStatus.running)]);
      expect(lights.of(_a), WorktreeLight.working);
      read([_run('1', _a, AgentStatus.needsYou)]);
      expect(lights.of(_a), WorktreeLight.done, reason: 'its turn ended');
      read([_run('1', _a, AgentStatus.needsYou)]);
      expect(lights.of(_a), WorktreeLight.done, reason: 'news stay');
      lights.seen(_a);
      expect(lights.of(_a), WorktreeLight.idle);
    });

    test('asking outranks working; a failure outranks both; Stop isn’t a failure', () {
      read([_run('1', _a, AgentStatus.running), _run('2', _a, AgentStatus.running), _run('3', _b, AgentStatus.running)]);
      read([_run('1', _a, AgentStatus.needsYou, asked: true), _run('2', _a, AgentStatus.running), _run('3', _b, AgentStatus.done, exit: 143)]);
      expect(lights.of(_a), WorktreeLight.asking);
      expect(lights.of(_b), WorktreeLight.idle, reason: 'stopped by you');
      read([_run('1', _a, AgentStatus.needsYou, asked: true), _run('2', _a, AgentStatus.done, exit: 2)]);
      expect(lights.of(_a), WorktreeLight.failed);
    });

    test('a run that fails before it was seen working is news too', () {
      read(const []);
      read([_run('1', _a, AgentStatus.done, exit: 127)]);
      expect(lights.of(_a), WorktreeLight.failed);
    });

    test('no news for the worktree on screen', () {
      read([_run('1', _a, AgentStatus.running)]);
      read([_run('1', _a, AgentStatus.done)], looking: _a);
      expect(lights.of(_a), WorktreeLight.idle);
    });

    test('an agent typed in a terminal counts where its folder is: the deepest worktree', () {
      read(const [], hand: const [TerminalAgent(terminalId: 'z', providerId: 'claude', name: 'claude', terminalTitle: 'zsh', cwd: '$_a/nested/src', busy: true)]);
      expect(lights.of('$_a/nested'), WorktreeLight.working);
      expect(lights.of(_a), WorktreeLight.idle);
    });
  });

  test('AppState: an agent finishing elsewhere lights its worktree until you open it', () {
    final agents = _Agents();
    final s = AppState(agents: agents);
    final repo = s.workspace.repos.first;
    final other = repo.worktrees.firstWhere((w) => !s.isActiveWorktree(w));
    expect(s.worktreeLight(other).light, isNot(WorktreeLight.failed));

    agents.set([_run('1', other.path, AgentStatus.running)]);
    expect(s.worktreeLight(other), (light: WorktreeLight.working, pulse: true));
    agents.set([_run('1', other.path, AgentStatus.done, exit: 1)]);
    expect(s.worktreeLight(other), (light: WorktreeLight.failed, pulse: false));

    s.selectWorktree(other.branch, path: other.path);
    expect(s.worktreeLight(other).light, isNot(WorktreeLight.failed), reason: 'seen');
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
