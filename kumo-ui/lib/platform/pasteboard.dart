import 'dart:async';

import 'package:flutter/services.dart';

import 'os/host_os.dart';
import 'os/macos.dart';

/// Files dropped on the window at [position] (logical pixels from its top
/// left).
typedef FileDrop = ({List<String> paths, Offset position});

/// The clipboard and dropped files, through the macOS runner
/// (`MainFlutterWindow.swift`). Elsewhere there is nothing: ⌘V pastes text.
class Pasteboard {
  Pasteboard._();

  static const _channel = MethodChannel('kumo/pasteboard');
  static final _drops = StreamController<FileDrop>.broadcast(onListen: () => _channel.setMethodCallHandler(_onCall));

  /// What a paste puts in as paths: copied files, or an image (a screenshot)
  /// saved as a PNG. Null when the clipboard's text is what goes in.
  static Future<List<String>?> paths() async {
    try {
      final paths = await _channel.invokeListMethod<String>('paths');
      return paths == null || paths.isEmpty ? null : paths;
    } on MissingPluginException {
      return null;
    }
  }

  static Stream<FileDrop> get drops => _drops.stream;

  /// Whether [chooseFile] opens a dialog here (the macOS runner).
  static bool get canChoose => hostOs is MacOs;

  /// A file picked with the system's open panel ([extensions] only), or
  /// null when cancelled or not available.
  static Future<String?> chooseFile({List<String> extensions = const [], String message = ''}) async {
    try {
      return await _channel.invokeMethod<String>('chooseFile', {'extensions': extensions, 'message': message});
    } on MissingPluginException {
      return null;
    }
  }

  static Future<Object?> _onCall(MethodCall call) async {
    if (call.method == 'drop') {
      final args = (call.arguments as Map).cast<String, Object?>();
      final paths = (args['paths'] as List).cast<String>();
      _drops.add((paths: paths, position: Offset((args['x'] as num).toDouble(), (args['y'] as num).toDouble())));
    }
    return null;
  }
}
