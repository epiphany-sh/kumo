import 'dart:io';

import 'os/host_os.dart';

/// Schemes Kumo hands to the OS: web pages and the task apps' own links.
const _schemes = {'https', 'http', 'obsidian', 'bear', 'todoist'};

/// Whether [openUrl] would hand [url] to the OS.
bool isOpenable(String url) => _schemes.contains(Uri.tryParse(url)?.scheme);

/// Opens [url] with the app the OS picks (browser, Obsidian, Bear). No
/// shell is involved, and only known schemes are opened.
Future<bool> openUrl(String url) async {
  if (!isOpenable(url)) return false;
  final (program, args) = hostOs.openUrlCommand(url);
  try {
    final result = await Process.run(program, args);
    return result.exitCode == 0;
  } on ProcessException {
    return false;
  }
}
