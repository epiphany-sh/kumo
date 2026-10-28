import 'dart:io' show Platform, Process;

import 'package:flutter/foundation.dart' show kIsWeb;

/// The user's name as git knows it (`user.name`), else the login: what
/// commits and the sidebar call "you". Read once.
final String gitUserName = _read();

String _read() {
  final login = kIsWeb ? '' : (Platform.environment['USER'] ?? Platform.environment['USERNAME'] ?? '');
  if (kIsWeb) return login;
  try {
    final r = Process.runSync('git', ['config', '--global', 'user.name']);
    final name = '${r.stdout}'.trim();
    if (r.exitCode == 0 && name.isNotEmpty) return name;
  } on Object {
    // No git: the login will do.
  }
  return login.isEmpty ? 'You' : login;
}
