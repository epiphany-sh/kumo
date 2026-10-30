import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/kumo_theme.dart';

part 'file_icons.g.dart';

/// Material Icon Theme's icon for a file or folder, by name and extension
/// (`assets/file_icons`, regenerated with `tool/file_icons.py`). Decorative:
/// the row next to it already says the name.
class FileIcon extends StatelessWidget {
  const FileIcon(this.path, {super.key, this.dir = false, this.open = false, this.size = 16});

  /// Relative path or bare name; a few icons depend on the parent folder.
  final String path;
  final bool dir;

  /// An expanded folder.
  final bool open;
  final double size;

  @override
  Widget build(BuildContext context) {
    final name = fileIconName(path, dir: dir, open: open, light: !context.c.isDark);
    return SvgPicture.asset('assets/file_icons/$name.svg', width: size, height: size, excludeFromSemantics: true);
  }
}

/// The icon's asset name: the whole file name first (`Cargo.toml`,
/// `.github/dependabot.yml`), then the longest extension (`d.ts` before
/// `ts`), then the generic file. Matching ignores case, like VS Code.
String fileIconName(String path, {bool dir = false, bool open = false, bool light = false}) {
  final segments = path.toLowerCase().split('/');
  var icon = dir ? _folderIcon(segments.last, open) : _fileIcon(segments);
  if (light && _lightIcons.contains(icon)) icon = '${icon}_light';
  return icon;
}

String _folderIcon(String name, bool open) {
  // `src`, `.src`, `_src`, `-src` and `__src__` share one entry.
  final base = name.length > 4 && name.startsWith('__') && name.endsWith('__') ? name.substring(2, name.length - 2) : (name.length > 1 && '._-'.contains(name[0]) ? name.substring(1) : name);
  final icon = _folders[base] ?? 'folder';
  return open ? '$icon-open' : icon;
}

String _fileIcon(List<String> segments) {
  final name = segments.last;
  if (segments.length > 1) {
    final nested = _fileNames['${segments[segments.length - 2]}/$name'];
    if (nested != null) return nested;
  }
  final whole = _fileNames[name];
  if (whole != null) return whole;
  // `.env` → `env`; `a.test.ts` → `test.ts`, then `ts`.
  for (var dot = name.indexOf('.'); dot != -1; dot = name.indexOf('.', dot + 1)) {
    final icon = _extensions[name.substring(dot + 1)];
    if (icon != null) return icon;
  }
  return 'file';
}
