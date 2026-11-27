import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/terminal/terminal_surface.dart';
import 'package:kumo_ui/terminal/terminal_view.dart';
import 'package:kumo_ui/theme/kumo_theme.dart';
import 'package:kumo_ui/theme/palette.dart';

/// A surface recording which views say they show it.
class _Spy implements VisibleSurface {
  final shownBy = <Object>{};
  final _buffer = ValueNotifier(const TermBuffer([]));

  bool get shown => shownBy.isNotEmpty;

  @override
  void setVisible(Object view, bool visible) => visible ? shownBy.add(view) : shownBy.remove(view);

  @override
  String get title => 'zsh';
  @override
  String get cwd => '~';
  @override
  ValueListenable<TermBuffer> get buffer => _buffer;
  @override
  bool get interactive => false;
  @override
  void sendText(String text) {}
  @override
  void sendBytes(List<int> bytes) {}
  @override
  void resize(int cols, int rows) {}
  @override
  void dispose() => _buffer.dispose();
}

Widget _app(Widget child) => KumoTheme(
      mode: KumoThemeMode.dark,
      palette: KumoPalette.dark,
      terminalPalette: KumoPalette.dark,
      child: MaterialApp(home: Scaffold(body: SizedBox(width: 600, height: 300, child: child))),
    );

void main() {
  testWidgets('a pane tells its surface whether the IndexedStack shows it', (tester) async {
    final a = _Spy(), b = _Spy();
    Widget stack(int index) => _app(IndexedStack(index: index, children: [TerminalCanvas(surface: a), TerminalCanvas(surface: b)]));

    await tester.pumpWidget(stack(0));
    expect((a.shown, b.shown), (true, false));
    await tester.pumpWidget(stack(1));
    expect((a.shown, b.shown), (false, true));

    await tester.pumpWidget(_app(const SizedBox()));
    expect((a.shown, b.shown), (false, false));
  });

  testWidgets('a pane with tickers off hides its surface', (tester) async {
    final s = _Spy();
    await tester.pumpWidget(_app(TickerMode(enabled: false, child: TerminalCanvas(surface: s))));
    expect(s.shown, isFalse);
    await tester.pumpWidget(_app(TickerMode(enabled: true, child: TerminalCanvas(surface: s))));
    expect(s.shown, isTrue);
  });

  testWidgets('a pane given another surface hands its view over', (tester) async {
    final a = _Spy(), b = _Spy();
    await tester.pumpWidget(_app(TerminalCanvas(surface: a)));
    expect(a.shown, isTrue);
    await tester.pumpWidget(_app(TerminalCanvas(surface: b)));
    expect((a.shown, b.shown), (false, true));
  });
}
