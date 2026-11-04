import 'dart:io';

import 'os/host_os.dart';

/// The workspace a window was opened for (`open -n … --env KUMO_WORKSPACE=<id>`).
String? get launchWorkspace {
  final v = Platform.environment['KUMO_WORKSPACE']?.trim();
  return v == null || v.isEmpty ? null : v;
}

/// Opens Kumo again, in its own window, on workspace [id]. Null when it
/// started; otherwise why it couldn't.
Future<String?> openWorkspaceWindow(String id) => hostOs.openWorkspaceWindow(id);
