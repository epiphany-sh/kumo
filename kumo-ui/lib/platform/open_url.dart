import 'dart:io';

/// Schemes Kumo hands to the OS: web pages and the task apps' own links.
const _schemes = {'https', 'http', 'obsidian', 'bear', 'todoist'};

/// Opens [url] with the app the OS picks (browser, Obsidian, Bear). No
/// shell is involved, and only known schemes are opened.
Future<bool> openUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !_schemes.contains(uri.scheme)) return false;
  final (program, args) = Platform.isMacOS
      ? ('open', [url])
      : Platform.isWindows
          ? ('rundll32', ['url.dll,FileProtocolHandler', url])
          : ('xdg-open', [url]);
  try {
    final result = await Process.run(program, args);
    return result.exitCode == 0;
  } on ProcessException {
    return false;
  }
}
