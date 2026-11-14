import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/terminal/ansi_screen.dart';
import 'package:kumo_ui/terminal/command_history.dart';
import 'package:kumo_ui/terminal/history_panel.dart';
import 'package:kumo_ui/terminal/terminal_surface.dart';
import 'package:kumo_ui/terminal/terminal_view.dart';
import 'package:kumo_ui/theme/kumo_theme.dart';
import 'package:kumo_ui/theme/palette.dart';

/// What Kumo's integration prints around a prompt: where it starts (A),
/// where you type (B), a command's output (C) and its end (D).
const a = '\x1b]133;A\x07';
const b = '\x1b]133;B\x07';
const c = '\x1b]133;C\x07';
String d(int exit) => '\x1b]133;D;$exit\x07';

AnsiScreen screen(String output, {int cols = 30}) => AnsiScreen(cols: cols, rows: 6)..feed(utf8.encode(output));

CommandHistory history(List<HistoryItem> items, {String cwd = '/w/app'}) => CommandHistory(items, cwd: cwd, repo: '/w/app');

void main() {
  group('what you type at the prompt', () {
    test('is the text from where you type to the cursor', () {
      final input = screen('$a\$ ${b}git st').snapshot().input!;
      expect(input.text, 'git st');
      expect(input.trailing, isFalse);
      expect(input.room, 30 - 8);
    });

    test('goes on over rows the line wraps to', () {
      final input = screen('$a\$ ${b}echo 0123456789012345678901234567890', cols: 20).snapshot().input!;
      expect(input.text, 'echo 0123456789012345678901234567890');
    });

    test('is nothing while a command runs, or without the shell saying where you type', () {
      expect(screen('$a\$ ${b}make\r\n${c}building').snapshot().input, isNull);
      expect(screen('$a\$ make').snapshot().input, isNull);
      expect(screen('$a\$ ${b}make\r\n$c${d(0)}$a\$ ${b}').snapshot().input!.text, '');
    });

    test('knows when something is drawn at the cursor', () {
      // Back two characters into the line.
      expect(screen('$a\$ ${b}git st\x1b[2D').snapshot().input!.trailing, isTrue);
      // Another tool's gray suggestion after the cursor.
      expect(screen('$a\$ ${b}git st\x1b[2matus\x1b[0m\x1b[5D').snapshot().input!.trailing, isTrue);
    });

    test('leaves room for a right prompt', () {
      final input = screen('$a\$ ${b}ls\x1b[s\x1b[1;25H10:42\x1b[u').snapshot().input!;
      expect(input.text, 'ls');
      expect(input.trailing, isFalse);
      expect(input.room, 24 - 4);
    });
  });

  group('the suggestion', () {
    test('is the rest of a command you ran that starts with what you typed', () {
      final h = history([const HistoryItem('git status'), const HistoryItem('git stash pop')]);
      expect(suggestCommand('git st', h), 'atus');
      expect(suggestCommand('git sta', h), 'tus');
      expect(suggestCommand('git status', h), isNull, reason: 'nothing left to add');
      expect(suggestCommand('', h), isNull);
      expect(suggestCommand('  ', h), isNull);
      expect(suggestCommand('ls', h), isNull);
    });

    test('prefers one run in this folder, then one that worked, then the last run', () {
      final h = history([
        const HistoryItem('cargo test -p web', lastExit: 101, lastCwd: '/w/app'),
        const HistoryItem('cargo test -p api', lastExit: 0, lastCwd: '/w/app/api'),
        const HistoryItem('cargo test --all', lastExit: 0, lastCwd: '/w/app'),
      ]);
      expect(suggestCommand('cargo t', h), 'est --all');
      expect(suggestCommand('cargo t', history(h.items, cwd: '/elsewhere')), 'est -p api');
    });

    test('is never a command of several lines or with control characters', () {
      final h = history([const HistoryItem('for f in *\ndo echo \$f\ndone'), const HistoryItem('echo \x1b[31mred')]);
      expect(suggestCommand('for', h), isNull);
      expect(suggestCommand('echo', h), isNull);
    });

    test('⌥→ takes the next word of it', () {
      expect(nextWord('atus --short'), 'atus');
      expect(nextWord(' --short -b'), ' --short');
      expect(nextWord(''), '');
    });

    test('the panel finds commands with every word you type', () {
      final items = [const HistoryItem('git push origin main'), const HistoryItem('git pull'), const HistoryItem('make push')];
      expect(filterHistory(items, 'push git').map((i) => i.command), ['git push origin main']);
      expect(filterHistory(items, '  '), items);
    });
  });

  group('in the terminal', () {
    Future<_Shell> pump(WidgetTester tester, {String typed = 'git st'}) async {
      final shell = _Shell(typed);
      await tester.pumpWidget(KumoTheme(
        mode: KumoThemeMode.dark,
        palette: KumoPalette.dark,
        terminalPalette: KumoPalette.dark,
        child: MaterialApp(home: Scaffold(body: SizedBox(width: 600, height: 200, child: TerminalCanvas(surface: shell, active: true)))),
      ));
      await tester.pump();
      return shell;
    }

    testWidgets('→ types the rest of the suggestion, ⌥→ its next word', (tester) async {
      final shell = await pump(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(shell.sent.map(utf8.decode), ['atus --short']);
      shell.sent.clear();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      expect(shell.sent.map(utf8.decode), ['atus']);
      expect(tester.takeException(), isNull);
    });

    testWidgets('without a suggestion → goes to the shell', (tester) async {
      final shell = await pump(tester, typed: 'ls');
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(shell.sent.map(utf8.decode), ['\x1b[C']);
    });
 
    testWidgets('the history panel finds a command and puts it at the prompt', (tester) async {
      final shell = _Shell('');
      shell._history.value = const CommandHistory([HistoryItem('git status --short', runs: 3), HistoryItem('make test', lastExit: 2)], repo: '/w/app');
      var atPrompt = false;
      await tester.pumpWidget(KumoTheme(
        mode: KumoThemeMode.dark,
        palette: KumoPalette.dark,
        terminalPalette: KumoPalette.dark,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(onPressed: () => showHistoryPanel(context, shell, atPrompt: () => atPrompt), child: const Text('open')),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.text('Commands run in app'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'make');
      await tester.pump();
      expect(find.text('git status --short'), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      // A command runs: nothing is typed into it.
      expect(shell.sent, isEmpty);
      expect(find.text('A command is running: wait for the prompt.'), findsOneWidget);
      atPrompt = true;
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(shell.sent.map(utf8.decode), ['make test']);
      expect(find.text('Command history'), findsNothing);
    });
  });
}

/// A shell at its prompt with [typed] typed, that remembers `git status
/// --short`.
class _Shell implements TerminalSurface, CommandHistorySource {
  _Shell(String typed) {
    _screen.feed(utf8.encode('$a\$ $b$typed'));
    _buffer.value = _screen.snapshot();
  }

  final _screen = AnsiScreen(cols: 60, rows: 8);
  final _buffer = ValueNotifier(const TermBuffer([]));
  final _history = ValueNotifier(const CommandHistory([HistoryItem('git status --short', lastExit: 0)]));
  final sent = <List<int>>[];

  @override
  String get title => 'zsh';
  @override
  String get cwd => '~';
  @override
  ValueListenable<TermBuffer> get buffer => _buffer;
  @override
  bool get interactive => true;
  @override
  void sendText(String text) => sendBytes(utf8.encode('$text\r'));
  @override
  void sendBytes(List<int> bytes) => sent.add(bytes);
  @override
  void resize(int cols, int rows) {}
  @override
  void dispose() => _buffer.dispose();

  @override
  ValueListenable<CommandHistory> get history => _history;
  @override
  Future<void> refreshHistory() async {}
  @override
  Future<int> forgetHistory({bool everything = false}) async => 0;
  @override
  void insertCommand(String command, {bool run = false}) => sendBytes(utf8.encode(command));
}
