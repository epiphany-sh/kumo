import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/app/kumo_app.dart';
import 'package:kumo_ui/data/models.dart';
import 'package:kumo_ui/data/pull_requests_source.dart';
import 'package:kumo_ui/data/workspace_source.dart';
import 'package:kumo_ui/widgets/kicons.dart';

Worktree _with(Worktree w, {int conflicts = 0, bool gone = false}) => Worktree(
      branch: w.branch,
      note: w.note,
      tone: w.tone,
      path: w.path,
      sync: w.sync,
      agent: w.agent,
      changes: w.changes,
      unpushed: w.unpushed,
      principal: w.principal,
      conflicts: conflicts,
      upstreamGone: gone,
    );

/// The design's first repo: TSK-412 mid-merge, TSK-398's branch merged
/// and deleted on the host.
class _Workspace extends MockWorkspaceSource {
  @override
  Repo? repo(String id) {
    final r = super.repo(id);
    if (r == null || r.name != 'repo-a') return r;
    return Repo(name: r.name, host: r.host, path: r.path, worktrees: [
      for (final w in r.worktrees)
        if (w.branch.contains('TSK-412'))
          _with(w, conflicts: 2)
        else if (w.branch.contains('TSK-398'))
          _with(w, gone: true)
        else
          w,
    ]);
  }
}

/// TSK-412 has an open pull request; nothing else has one.
class _Prs extends MockPullRequests {
  @override
  Future<BranchPullRequest> forBranch(String worktreePath, {bool refresh = false}) async => BranchPullRequest(
        pullRequest: worktreePath.endsWith('TSK-412')
            ? const PullRequestInfo(number: 9, label: '#9', title: 'bulk discounts', author: 'someone', branch: 'feat/TSK-412-bulk-discounts')
            : null,
      );
}

void main() {
  testWidgets('conflicts outrank the pull request; a branch gone from its remote shows without one', (tester) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState(demoWallpaper: true, workspace: _Workspace(), pullRequests: _Prs());
    await tester.pumpWidget(KumoApp(state: state));
    await tester.pump();
    await tester.pump();

    final conflicts = find.byTooltip('2 merge conflicts');
    expect(conflicts, findsOneWidget);
    expect(tester.widget<Icon>(find.descendant(of: conflicts, matching: find.byType(Icon))).icon, KIcons.warning);
    expect(find.byTooltip('#9 open'), findsNothing, reason: 'one mark at most: the conflicts');

    final gone = find.byTooltip('Its remote branch is gone: merged or deleted');
    expect(gone, findsOneWidget);
    expect(tester.widget<Icon>(find.descendant(of: gone, matching: find.byType(Icon))).icon, KIcons.merged);
    expect(tester.takeException(), isNull);
  });
}
