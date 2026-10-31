import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/app/kumo_app.dart';
import 'package:kumo_ui/data/agents_source.dart';
import 'package:kumo_ui/data/models.dart';
import 'package:kumo_ui/editor/ask_agent.dart';
import 'package:kumo_ui/shell/app_shell.dart';
import 'package:kumo_ui/theme/kumo_theme.dart';
import 'package:kumo_ui/theme/palette.dart';
import 'package:kumo_ui/views/docs_screen.dart';

const _repo = 'internal/discount/repository.go';

/// One agent running in the selected worktree, recording what it's sent.
class _Agents extends MockAgentsSource {
  String worktree = '';
  final sent = <String>[];

  @override
  List<AgentRun> get runs => [
        AgentRun(
          id: 'a1',
          providerId: 'claude',
          providerName: 'Claude Code',
          short: 'CC',
          worktreePath: worktree,
          terminalId: 't1',
          title: 'PRC-412 bulk discounts',
          status: AgentStatus.running,
          startedAt: DateTime(2026, 10, 30, 13, 54),
        ),
      ];

  @override
  Future<bool> addContext(String id, AgentContextItem item, {String text = ''}) async {
    sent.add(text);
    return true;
  }
}

Future<AppState> _app(WidgetTester tester, {AgentsSource? agents}) async {
  tester.view.physicalSize = const Size(1440, 960);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final state = AppState(demoWallpaper: true, agents: agents);
  await tester.pumpWidget(KumoApp(state: state));
  await tester.pump();
  return state;
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

void main() {
  group('ask an agent about selected code', () {
    test('the lines a selection covers, and the message the agent gets', () {
      const text = 'a\nbb\nccc\ndddd\n';
      expect(selectedLines(text, const TextSelection.collapsed(offset: 2)), isNull);
      expect(selectedLines(text, const TextSelection(baseOffset: 2, extentOffset: 7)), (2, 3));
      expect(selectedLines(text, const TextSelection(baseOffset: 9, extentOffset: 2)), (2, 3), reason: 'ending at a line start leaves that line out');
      final m = askAgentMessage(
        repo: 'price-admin',
        worktree: '/wt/price-admin/PRC-412',
        branch: 'feat/PRC-412',
        path: _repo,
        lines: (20, 26),
        firstLine: '  func (r *Repository) Upsert(',
        note: 'Look for bugs.',
      );
      expect(m, 'In price-admin, worktree /wt/price-admin/PRC-412, branch feat/PRC-412: look at $_repo, lines 20–26 (starts with `func (r *Repository) Upsert(`). Look for bugs.');
      expect(m.contains('\n'), isFalse, reason: 'one line: it types into the agent’s terminal as one message');
    });

    testWidgets('select code in the Files tab, write a note, send it to the agent running here', (tester) async {
      final agents = _Agents();
      final state = await _app(tester, agents: agents);
      agents.worktree = state.workspace.absolutePathOf(state.activeWorktreeEntry!);
      await tester.tap(find.byTooltip(ContextTab.files.tooltip));
      await tester.pump();
      await tester.tap(find.text('repository.go').first);
      await _settle(tester);
      final ctrl = state.buffers.of(_repo);
      final start = ctrl.text.indexOf('type Repository');
      ctrl.selection = TextSelection(baseOffset: start, extentOffset: ctrl.text.indexOf('}', start) + 1);
      await tester.pump();
      expect(find.text('Ask agent'), findsOneWidget, reason: 'a pill under the selection');

      await tester.tap(find.text('Ask agent'));
      await _settle(tester);
      final (from, to) = selectedLines(ctrl.text, ctrl.selection)!;
      expect(find.text('Ask an agent about lines $from–$to'), findsOneWidget);
      expect(find.text('$_repo:$from-$to'), findsOneWidget, reason: 'what goes with the note');
      await tester.tap(find.text('Find bugs'));
      await tester.pump();
      await tester.tap(find.text('Send to Claude Code ⌘↩'));
      await _settle(tester);
      expect(agents.sent.single, contains('$_repo, lines $from–$to'));
      expect(agents.sent.single, endsWith('Look for bugs or edge cases here.'));
      expect(find.text('Sent to Claude Code'), findsOneWidget);
      expect(find.text('Message sent'), findsOneWidget, reason: 'the exact message stays on screen');
      await tester.tap(find.text('Done'));
      await _settle(tester);
      expect(find.text('Message sent'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('sidebar', () {
    testWidgets('its right edge drags the width between 220 and 420; double-click resets it', (tester) async {
      final state = await _app(tester);
      expect(state.sidebarWidth, 252);
      await tester.drag(find.byType(SidebarResizer), const Offset(100, 0));
      await tester.pump();
      expect(state.sidebarWidth, greaterThan(300));
      await tester.drag(find.byType(SidebarResizer), const Offset(600, 0));
      await tester.pump();
      expect(state.sidebarWidth, 420, reason: 'never wider than 420');
      await tester.drag(find.byType(SidebarResizer), const Offset(-900, 0));
      await tester.pump();
      expect(state.sidebarWidth, 220, reason: 'never narrower than 220');
      await tester.tap(find.byType(SidebarResizer));
      await tester.pump(const Duration(milliseconds: 60));
      await tester.tap(find.byType(SidebarResizer));
      await tester.pump(const Duration(milliseconds: 400));
      expect(state.sidebarWidth, AppState.defaultSidebarWidth);
      expect(state.prefs.get<num>('sidebar.width', 0), AppState.defaultSidebarWidth, reason: 'kept for the next launch');
      expect(tester.takeException(), isNull);
    });

    testWidgets('a worktree shows its whole name and path on hover; right-click copies either', (tester) async {
      final state = await _app(tester);
      final w = state.activeWorktreeEntry!;
      expect(find.byTooltip('${w.branch}\n${state.workspace.absolutePathOf(w)}\nRight-click for actions'), findsOneWidget);
      await tester.tap(find.text(w.branch).first, buttons: kSecondaryButton);
      await tester.pump();
      expect(find.text('Copy full path'), findsOneWidget);
      await tester.tap(find.text('Copy branch name'));
      await tester.pump();
      expect(find.text('Copied branch name'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1700));
      expect(find.text('Copied branch name'), findsNothing, reason: 'it goes back to the worktree’s status');
    });
  });

  group('docs', () {
    Future<AppState> docs(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final state = AppState()..view = KumoView.docs;
      await tester.pumpWidget(AppScope(
        state: state,
        child: KumoTheme(
          mode: KumoThemeMode.dark,
          palette: KumoPalette.dark,
          terminalPalette: KumoPalette.dark,
          child: const MaterialApp(home: Scaffold(body: DocsScreen())),
        ),
      ));
      await _settle(tester);
      return state;
    }

    testWidgets('Browse walks a knowledge base one level at a time, with a breadcrumb', (tester) async {
      await docs(tester);
      await tester.tap(find.text('Browse'));
      await _settle(tester);
      expect(find.text('Pricing'), findsWidgets);
      await tester.tap(find.byTooltip('Pricing').first);
      await _settle(tester);
      await tester.tap(find.byTooltip('Engineering').first);
      await _settle(tester);
      await tester.tap(find.byTooltip('Discounts').first);
      await _settle(tester);
      expect(find.text('Discount rules v2'), findsOneWidget);
      expect(find.text('archived'), findsOneWidget);
      // A page with pages under it: its › goes in.
      await tester.tap(find.byTooltip('1 page under Bulk discounts · design'));
      await _settle(tester);
      expect(find.text('Open questions'), findsOneWidget);
      expect(find.text('…'), findsOneWidget, reason: 'a long trail folds its middle');
      await tester.tap(find.byTooltip('Up one level'));
      await _settle(tester);
      expect(find.text('Discount rules v2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('For you keeps the pages you pin and the ones you open', (tester) async {
      await docs(tester);
      expect(find.text('Pin a page from its header to keep it here.'), findsOneWidget);
      await tester.tap(find.byTooltip('Pin to For you'));
      await tester.pump();
      expect(find.byTooltip('Unpin from For you'), findsOneWidget);
      expect(find.text('Pin a page from its header to keep it here.'), findsNothing);
      await tester.tap(find.text('PRC-412 scratchpad').first);
      await _settle(tester);
      expect(find.text('RECENT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
