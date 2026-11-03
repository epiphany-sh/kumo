import 'dart:io';

/// The workspace a window was opened for (`open -n … --env KUMO_WORKSPACE=<id>`).
String? get launchWorkspace {
  final v = Platform.environment['KUMO_WORKSPACE']?.trim();
  return v == null || v.isEmpty ? null : v;
}

/// Opens Kumo again, in its own window, on workspace [id]. Null when it
/// started; otherwise why it couldn't.
Future<String?> openWorkspaceWindow(String id) async {
  if (!Platform.isMacOS) return 'Opening a workspace in a new window works on macOS for now.';
  // …/Kumo.app/Contents/MacOS/Kumo → …/Kumo.app
  final exe = Platform.resolvedExecutable;
  final at = exe.indexOf('.app/');
  if (at < 0) return 'Kumo isn’t running from its app bundle, so it can’t open another window.';
  final bundle = exe.substring(0, at + 4);
  try {
    final r = await Process.run('open', ['-n', '--env', 'KUMO_WORKSPACE=$id', bundle]);
    return r.exitCode == 0 ? null : 'macOS couldn’t open another Kumo window: ${(r.stderr as Object).toString().trim()}';
  } on ProcessException catch (e) {
    return 'macOS couldn’t open another Kumo window: ${e.message}';
  }
}
