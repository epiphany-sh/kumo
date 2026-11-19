import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/platform/app_icon.dart';
import 'package:kumo_ui/platform/os/host_os.dart';
import 'package:kumo_ui/platform/os/linux.dart';
import 'package:kumo_ui/platform/os/macos.dart';
import 'package:kumo_ui/platform/os/windows.dart';
import 'package:kumo_ui/platform/pasteboard.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// The system dialog, answering [picked] and keeping what it was asked.
class _Dialog extends FileSelectorPlatform with MockPlatformInterfaceMixin {
  _Dialog(this.picked);
  final String? picked;
  List<XTypeGroup>? groups;
  String? title;

  @override
  Future<XFile?> openFile({List<XTypeGroup>? acceptedTypeGroups, String? initialDirectory, String? confirmButtonText}) async {
    groups = acceptedTypeGroups;
    return picked == null ? null : XFile(picked!);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() => debugHostOs = null);

  group('off macOS the system file dialog comes from file_selector', () {
    for (final os in [WindowsOs(const {}), LinuxOs(const {})]) {
      test(os.runtimeType.toString(), () async {
        debugHostOs = os;
        final dialog = _Dialog(r'C:\Users\user-1\agent.md');
        FileSelectorPlatform.instance = dialog;
        expect(Pasteboard.canChoose, isTrue);
        expect(await Pasteboard.chooseFile(extensions: const ['md', 'txt']), r'C:\Users\user-1\agent.md');
        expect(dialog.groups?.single.extensions, ['md', 'txt']);

        FileSelectorPlatform.instance = _Dialog(null);
        expect(await Pasteboard.chooseFile(), isNull, reason: 'cancelled');
      });
    }

    test('an icon of your own still needs the macOS runner', () {
      debugHostOs = WindowsOs(const {'APPDATA': r'C:\Users\test\AppData\Roaming'});
      expect(AppIcons.canMakeOwn, isFalse);
    });
  });

  test('macOS keeps its runner’s open panel', () async {
    debugHostOs = MacOs(const {'HOME': '/Users/test'});
    FileSelectorPlatform.instance = _Dialog('/wrong');
    final calls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('kumo/pasteboard'), (call) async {
      calls.add(call);
      return '/Users/test/agent.md';
    });
    addTearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(const MethodChannel('kumo/pasteboard'), null));
    expect(Pasteboard.canChoose, isTrue);
    expect(await Pasteboard.chooseFile(extensions: const ['md']), '/Users/test/agent.md');
    expect(calls.single.method, 'chooseFile');
  });
}
