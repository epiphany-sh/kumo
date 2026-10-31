import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/app/app_state.dart';
import 'package:kumo_ui/app/kumo_app.dart';
import 'package:kumo_ui/shell/side_panel.dart';
import 'package:kumo_ui/widgets/file_icon.dart';

void main() {
  test('files get their icon by name, then by the longest extension', () {
    expect(fileIconName('src/main.rs'), 'rust');
    expect(fileIconName('types/index.d.ts'), 'typescript-def');
    expect(fileIconName('app.ts'), 'typescript');
    expect(fileIconName('README.md'), 'readme', reason: 'the whole name wins over .md');
    expect(fileIconName('Dockerfile'), 'docker', reason: 'case does not matter');
    expect(fileIconName('.env'), 'tune');
    expect(fileIconName('notes.unknownext'), 'file');
  });

  test('folders get their icon by name, open or closed', () {
    expect(fileIconName('crates/src', dir: true), 'folder-src');
    expect(fileIconName('src', dir: true, open: true), 'folder-src-open');
    expect(fileIconName('.github', dir: true), 'folder-github');
    expect(fileIconName('__tests__', dir: true), 'folder-test');
    expect(fileIconName('whatever', dir: true, open: true), 'folder-open');
  });

  test('light backgrounds use the light variant when there is one', () {
    expect(fileIconName('Cargo.toml', light: true), 'toml_light');
    expect(fileIconName('main.rs', light: true), 'rust');
  });

  test('the icons are bundled', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    for (final name in ['file', 'folder', 'folder-open', 'rust', 'toml_light', 'folder-src-open']) {
      expect(await rootBundle.loadString('assets/file_icons/$name.svg'), startsWith('<svg'), reason: name);
    }
  });

  testWidgets('the files tree shows colored icons unless Settings says simple', (tester) async {
    tester.view.physicalSize = const Size(1440, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = AppState(demoWallpaper: true);
    await tester.pumpWidget(KumoApp(state: state));
    await tester.pump();
    await tester.tap(find.byTooltip('Files'));
    await tester.pump();

    final icons = find.descendant(of: find.byType(WorktreeFilesTree), matching: find.byType(SvgPicture));
    expect(icons, findsWidgets);

    state.colorFileIcons = false;
    await tester.pump();
    expect(icons, findsNothing);
    expect(find.descendant(of: find.byType(WorktreeFilesTree), matching: find.byIcon(Icons.folder_outlined)), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
