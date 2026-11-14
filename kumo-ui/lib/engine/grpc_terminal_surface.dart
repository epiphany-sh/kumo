import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:grpc/grpc.dart';

import '../platform/os/host_os.dart';
import '../terminal/ansi_screen.dart';
import '../terminal/command_history.dart';
import '../terminal/terminal_surface.dart';
import 'generated/kumo/v1/kumo.pbgrpc.dart';
import 'kumo_engine.dart';

/// A terminal running in `kumod`, shown through `Terminals.Attach`.
///
/// Output is parsed as it arrives but published at most once per frame
/// (kumo.md §5.6). Keystrokes typed before the stream is up are queued.
class GrpcTerminalSurface implements TerminalModes, CommandHistorySource {
  /// Opens the user's login shell in [directory] (their home directory by
  /// default). The PTY is opened at the pane's real size, once it is first
  /// laid out.
  ///
  /// [adopt] may hand over a terminal the daemon already runs instead.
  ///
  /// With [rememberCommands], the daemon remembers what it runs (Settings →
  /// Terminal).
  GrpcTerminalSurface.shell(this._engine, {String? directory, this.onExit, Future<TerminalInfo?> Function()? adopt, this.rememberCommands = true})
      : title = _shellName,
        cwd = _shorten(directory),
        _directory = directory,
        _existingId = null,
        killOnClose = true,
        _adopt = adopt {
    _run();
  }

  /// Re-attaches to a terminal the daemon kept running, replaying its output.
  /// With [killOnClose] false, closing the pane only detaches (agents keep
  /// running and are managed from the Agents view).
  GrpcTerminalSurface.attach(
    this._engine, {
    required String terminalId,
    required String program,
    String? title,
    String? directory,
    this.onExit,
    this.killOnClose = true,
  })  : title = title ?? program.split(Platform.pathSeparator).last,
        cwd = _shorten(directory),
        _directory = directory,
        _existingId = terminalId,
        rememberCommands = false,
        _adopt = null {
    _run();
  }

  final KumoEngine _engine;
  final String? _existingId;
  final String? _directory;

  /// Whether closing the pane kills the process (shells) or only detaches.
  final bool killOnClose;
  final Future<TerminalInfo?> Function()? _adopt;

  /// Called with the exit code when the process ends.
  final void Function(int exitCode)? onExit;

  /// A new shell remembers what it runs (one adopted or re-attached keeps
  /// what it was opened with).
  final bool rememberCommands;

  @override
  final String title;
  @override
  final String cwd;

  late final AnsiScreen _screen = AnsiScreen(onReply: sendBytes);
  final _buffer = ValueNotifier(const TermBuffer([], cursorVisible: false));
  final _size = Completer<(int, int)>();
  final _pending = <List<int>>[];
  StreamController<TerminalInput>? _input;
  ResponseStream<TerminalOutput>? _output;
  String? _terminalId;
  int _seq = 0;
  bool _exited = false;
  bool _frameScheduled = false;
  bool _disposed = false;
  Timer? _resizeTimer;
  final _history = ValueNotifier(CommandHistory.empty);
  int _seenDone = -1;
  Timer? _historyTimer;
  Future<void>? _historyRead;

  @override
  ValueListenable<TermBuffer> get buffer => _buffer;

  @override
  bool get interactive => true;

  @override
  ValueListenable<CommandHistory> get history => _history;

  @override
  Future<void> refreshHistory() {
    final id = _terminalId;
    final conn = _engine.current;
    if (id == null || conn == null || _disposed) return Future.value();
    // One read at a time: a burst of finished commands (a replay) needs
    // only the last.
    return _historyRead ??= () async {
      try {
        final reply = await conn.terminals.history(HistoryRequest(terminalId: id));
        if (_disposed) return;
        _history.value = CommandHistory(
          [
            for (final e in reply.entries)
              HistoryItem(
                e.command,
                runs: e.runs,
                lastRun: DateTime.fromMicrosecondsSinceEpoch((e.lastRunUnixNanos ~/ 1000).toInt()),
                lastExit: e.hasLastExit() ? e.lastExit : null,
                lastCwd: e.lastCwd,
              ),
          ],
          cwd: reply.cwd,
          repo: reply.repo,
        );
      } on Object {
        // An older daemon, or gone: no history to suggest from.
      } finally {
        _historyRead = null;
      }
    }();
  }

  @override
  Future<int> forgetHistory({bool everything = false}) async {
    final id = _terminalId;
    final conn = _engine.current;
    if (id == null || conn == null) return 0;
    final reply = await conn.terminals.forgetHistory(ForgetHistoryRequest(terminalId: id, everything: everything));
    await refreshHistory();
    return reply.forgotten;
  }

  @override
  void insertCommand(String command, {bool run = false}) {
    // ⌃E ⌃U: to the end of the line, then erase it, in emacs-style line
    // editing (zsh, bash and fish by default).
    final line = command.contains('\n') && bracketedPaste ? '\x1b[200~$command\x1b[201~' : command;
    sendBytes([0x05, 0x15, ...utf8.encode(line), if (run) 0x0d]);
  }

  /// A command finished: what the daemon remembers changed.
  void _historyMaybeChanged() {
    final done = _screen.commandsDone;
    if (done == _seenDone) return;
    _seenDone = done;
    _historyTimer?.cancel();
    _historyTimer = Timer(const Duration(milliseconds: 60), refreshHistory);
  }

  @override
  bool get applicationCursorKeys => _screen.applicationCursorKeys;
  @override
  bool get bracketedPaste => _screen.bracketedPaste;
  @override
  bool get mouseTracking => _screen.mouseTracking;
  @override
  bool get mouseDrags => _screen.mouseDrags;
  @override
  bool get mouseHover => _screen.mouseHover;
  @override
  bool get sgrMouse => _screen.sgrMouse;

  /// Forgets the lines above the screen (the daemon's replay keeps them
  /// for the next attach).
  void clearScrollback() {
    _screen.clearScrollback();
    _render();
  }

  static String get _shellPath => hostOs.shell;

  static String get _shellName => _shellPath.split(Platform.pathSeparator).last;

  static String get _home => hostOs.home ?? '';

  /// `/Users/ana/wt/x` → `~/wt/x`, for the pane header.
  static String _shorten(String? directory) {
    final home = _home;
    if (directory == null || directory.isEmpty || directory == home) return '~';
    return home.isNotEmpty && directory.startsWith('$home${Platform.pathSeparator}') ? '~${directory.substring(home.length)}' : directory;
  }

  Future<void> _run() async {
    final (cols, rows) = await _size.future;
    try {
      final conn = await _engine.connection();
      if (_disposed) return;
      final existing = _existingId ?? (await _adopt?.call())?.terminalId;
      final id = existing ?? (await conn.terminals.open(_shellRequest(cols, rows))).terminalId;
      _terminalId = id;
      if (_disposed) {
        unawaited(_closeRemote(conn));
        return;
      }
      final input = _input = StreamController<TerminalInput>()
        ..add(TerminalInput(attach: AttachTo(terminalId: id, replayScrollback: true)));
      if (existing != null) input.add(TerminalInput(resize: Resize(cols: _screen.cols, rows: _screen.rows)));
      for (final bytes in _pending) {
        input.add(TerminalInput(data: bytes));
      }
      _pending.clear();

      final output = _output = conn.terminals.attach(input.stream);
      unawaited(refreshHistory());
      await for (final message in output) {
        if (message.hasOutput()) {
          _screen.feed(message.output.data);
          _seq = message.output.seq.toInt();
          _scheduleFrame();
        } else if (message.hasExited()) {
          _onExited(message.exited.exitCode);
        }
      }
    } on GrpcError catch (e) {
      if (!_disposed && e.code != StatusCode.cancelled) _showError(e.message ?? e.codeName);
    } on Object catch (e) {
      if (!_disposed) _showError('$e');
    }
  }

  OpenRequest _shellRequest(int cols, int rows) {
    final env = Platform.environment;
    final directory = _directory;
    return OpenRequest(
      program: _shellPath,
      args: hostOs.shellArgs,
      cwd: directory == null || directory.isEmpty ? _home : directory,
      env: {
        'TERM_PROGRAM': 'kumo',
        if (!env.containsKey('LANG')) 'LANG': 'en_US.UTF-8',
      }.entries,
      cols: cols,
      rows: rows,
      // zsh, bash and fish mark what you run (see YourLines).
      shellIntegration: true,
      rememberCommands: rememberCommands,
    );
  }

  void _onExited(int code) {
    _exited = true;
    _screen.feed(utf8.encode('\r\n\x1b[2m[process exited with code $code]\x1b[0m'));
    _render();
    onExit?.call(code);
  }

  void _showError(String message) {
    _screen.feed(utf8.encode('\x1b[31mkumod unavailable: $message\x1b[0m\r\n'));
    _render();
  }

  void _scheduleFrame() {
    if (_frameScheduled) return;
    _frameScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback((_) {
      _frameScheduled = false;
      _render();
    });
  }

  void _render() {
    if (_disposed) return;
    _buffer.value = _screen.snapshot(seq: _seq);
    _historyMaybeChanged();
  }

  @override
  void sendText(String text) {
    if (text.isEmpty) return;
    sendBytes(utf8.encode('$text\r'));
  }

  @override
  void sendBytes(List<int> bytes) {
    if (_disposed || _exited || bytes.isEmpty) return;
    final input = _input;
    if (input == null) {
      _pending.add(bytes);
    } else {
      input.add(TerminalInput(data: bytes));
    }
  }

  @override
  void resize(int cols, int rows) {
    if (cols == _screen.cols && rows == _screen.rows && _size.isCompleted) return;
    _screen.resize(cols, rows);
    _render();
    if (!_size.isCompleted) {
      _size.complete((cols, rows));
    } else {
      // Dragging a split resizes every frame: the program hears the last
      // size only, so it redraws once instead of on top of itself.
      _resizeTimer?.cancel();
      _resizeTimer = Timer(const Duration(milliseconds: 80), () {
        if (!_disposed) _input?.add(TerminalInput(resize: Resize(cols: _screen.cols, rows: _screen.rows)));
      });
    }
  }

  /// Closing the pane kills the process in the daemon, unless the surface
  /// only detaches ([killOnClose]).
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _resizeTimer?.cancel();
    _historyTimer?.cancel();
    final conn = _engine.current;
    if (killOnClose && conn != null && _terminalId != null) unawaited(_closeRemote(conn));
    _input?.close();
    _output?.cancel();
    _buffer.dispose();
    _history.dispose();
  }

  Future<void> _closeRemote(EngineConnection conn) async {
    try {
      await conn.terminals.close(CloseRequest(terminalId: _terminalId));
    } on Object {
      // Already gone.
    }
  }
}
