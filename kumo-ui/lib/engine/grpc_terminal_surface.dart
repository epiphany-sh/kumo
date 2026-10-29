import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:grpc/grpc.dart';

import '../terminal/ansi_screen.dart';
import '../terminal/terminal_surface.dart';
import 'generated/kumo/v1/kumo.pbgrpc.dart';
import 'kumo_engine.dart';

/// A terminal running in `kumod`, shown through `Terminals.Attach`.
///
/// Output is parsed as it arrives but published at most once per frame
/// (kumo.md §5.6). Keystrokes typed before the stream is up are queued.
class GrpcTerminalSurface implements TerminalSurface {
  /// Opens the user's login shell in [directory] (their home directory by
  /// default). The PTY is opened at the pane's real size, once it is first
  /// laid out.
  ///
  /// [adopt] may hand over a terminal the daemon already runs instead.
  GrpcTerminalSurface.shell(this._engine, {String? directory, this.onExit, Future<TerminalInfo?> Function()? adopt})
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

  @override
  ValueListenable<TermBuffer> get buffer => _buffer;

  @override
  bool get interactive => true;

  bool get applicationCursorKeys => _screen.applicationCursorKeys;
  bool get bracketedPaste => _screen.bracketedPaste;
  bool get mouseTracking => _screen.mouseTracking;
  bool get sgrMouse => _screen.sgrMouse;

  /// Forgets the lines above the screen (the daemon's replay keeps them
  /// for the next attach).
  void clearScrollback() {
    _screen.clearScrollback();
    _render();
  }

  static String get _shellPath =>
      Platform.environment['SHELL'] ?? (Platform.isWindows ? (Platform.environment['COMSPEC'] ?? 'cmd.exe') : '/bin/zsh');

  static String get _shellName => _shellPath.split(Platform.pathSeparator).last;

  static String get _home => Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '';

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
      args: Platform.isWindows ? const [] : const ['-l'],
      cwd: directory == null || directory.isEmpty ? _home : directory,
      env: {
        'TERM_PROGRAM': 'kumo',
        if (!env.containsKey('LANG')) 'LANG': 'en_US.UTF-8',
      }.entries,
      cols: cols,
      rows: rows,
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
    final conn = _engine.current;
    if (killOnClose && conn != null && _terminalId != null) unawaited(_closeRemote(conn));
    _input?.close();
    _output?.cancel();
    _buffer.dispose();
  }

  Future<void> _closeRemote(EngineConnection conn) async {
    try {
      await conn.terminals.close(CloseRequest(terminalId: _terminalId));
    } on Object {
      // Already gone.
    }
  }
}
