import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show AppExitResponse;

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/platform/updates.dart';
import 'package:kumo_ui/platform/updates_windows.dart';

const _repo = 'epiphany-sh/kumo';
const _feedUrl = 'https://api.github.com/repos/$_repo/releases?per_page=20';
const _localAppData = r'C:\Users\me\AppData\Local';
const _installedExe = r'C:\Users\me\AppData\Local\Programs\Kumo\Kumo.exe';

String _zipUrl(String v) => 'https://github.com/$_repo/releases/download/v$v/Kumo-$v-windows-x64.zip';

/// A release as GitHub's API lists it.
Map<String, Object?> _release(String version, {bool draft = false, bool prerelease = false, bool sig = true, bool sha = true, String? tag}) => {
      'tag_name': tag ?? 'v$version',
      'draft': draft,
      'prerelease': prerelease,
      'assets': [
        {'name': 'Kumo-$version.dmg', 'browser_download_url': 'https://github.com/$_repo/releases/download/v$version/Kumo-$version.dmg'},
        {'name': 'Kumo-$version-windows-x64.zip', 'browser_download_url': _zipUrl(version)},
        if (sig) {'name': 'Kumo-$version-windows-x64.zip.sig', 'browser_download_url': '${_zipUrl(version)}.sig'},
        if (sha) {'name': 'Kumo-$version-windows-x64.zip.sha256', 'browser_download_url': '${_zipUrl(version)}.sha256'},
        {'name': 'install.ps1', 'browser_download_url': 'https://github.com/$_repo/releases/download/v$version/install.ps1'},
      ],
    };

/// GitHub, answering from a table of URLs.
class _FakeHttp implements UpdateHttp {
  final replies = <String, HttpReply>{};
  final gets = <(String, Map<String, String>)>[];
  final downloads = <String>[];

  /// Runs once a download has been written, with the file it went to.
  void Function(File to)? afterDownload;

  void json(String url, Object body, {Map<String, String> headers = const {}}) => replies[url] = HttpReply(200, headers, utf8.encode(jsonEncode(body)));
  void bytes(String url, List<int> body) => replies[url] = HttpReply(200, const {}, body);
  void text(String url, String body) => bytes(url, utf8.encode(body));

  @override
  Future<HttpReply> get(Uri url, {Map<String, String> headers = const {}}) async {
    gets.add((url.toString(), headers));
    return replies[url.toString()] ?? const HttpReply(404, {}, []);
  }

  @override
  Future<void> download(Uri url, File to) async {
    downloads.add(url.toString());
    final reply = replies[url.toString()];
    if (reply == null || reply.status != 200) throw HttpException('404', uri: url);
    await to.writeAsBytes(reply.body);
    afterDownload?.call(to);
  }

  int feedGets() => gets.where((g) => g.$1 == _feedUrl).length;
}

/// Starts nothing; remembers what it was asked.
class _FakeLauncher implements UpdateLauncher {
  _FakeLauncher(this.calls);
  final List<String> calls;
  final started = <(String, List<String>)>[];
  var fail = false;

  @override
  int get pid => 4242;

  @override
  Future<void> start(String exe, List<String> args) async {
    if (fail) throw const ProcessException('powershell', [], 'nope');
    calls.add('start');
    started.add((exe, args));
  }

  @override
  void exit(int code) => calls.add('exit $code');
}

/// Timers that run when the test says.
class _FakeTimers {
  final pending = <({Duration after, void Function() run, _FakeTimer timer})>[];

  Timer call(Duration after, void Function() run) {
    final t = _FakeTimer();
    pending.add((after: after, run: run, timer: t));
    return t;
  }

  List<Duration> get delays => [for (final p in pending) if (p.timer.isActive) p.after];

  /// Runs the timers due, as if their time came.
  void fire() {
    final due = [for (final p in pending) if (p.timer.isActive) p];
    pending.clear();
    for (final p in due) {
      p.timer.cancel();
      p.run();
    }
  }
}

class _FakeTimer implements Timer {
  var _active = true;
  @override
  void cancel() => _active = false;
  @override
  bool get isActive => _active;
  @override
  int get tick => 0;
}

/// A signed release, its zip and its feed, and an updater to check it.
class _World {
  _World._(this.dir, this.keyPair, this.publicKey);

  static Future<_World> make() async {
    final dir = await Directory.systemTemp.createTemp('kumo-updates-');
    final keyPair = await Ed25519().newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    return _World._(dir, keyPair, publicKey);
  }

  final Directory dir;
  final SimpleKeyPair keyPair;
  final SimplePublicKey publicKey;
  final http = _FakeHttp();
  final calls = <String>[];
  late final launcher = _FakeLauncher(calls);
  final timers = _FakeTimers();
  var now = DateTime.utc(2026, 11, 19, 12);
  var auto = true;

  /// The zips extracted, and what they held.
  final extracted = <(String, String)>[];

  /// The update folders' names in [dir].
  List<String> folders() => [for (final e in dir.listSync()) if (e is Directory) e.uri.pathSegments.lastWhere((s) => s.isNotEmpty)];

  /// What the extracted Kumo.exe says it is, by zip content.
  String Function(String zipText) exeVersion = (zip) => '${zip.split(' ').last}+77';

  String get key => base64.encode(publicKey.bytes);

  /// Publishes [releases]; each version's zip is signed (and hashed) unless
  /// told otherwise.
  Future<void> publish(List<Map<String, Object?>> releases, {Map<String, String> headers = const {}}) async {
    http.json(_feedUrl, releases, headers: headers);
    for (final r in releases) {
      final version = (r['tag_name']! as String).replaceFirst('v', '');
      final zip = utf8.encode('zip of Kumo $version');
      http.bytes(_zipUrl(version), zip);
      final sig = await Ed25519().sign(zip, keyPair: keyPair);
      http.text('${_zipUrl(version)}.sig', base64.encode(sig.bytes));
      final sha = await Sha256().hash(zip);
      http.text('${_zipUrl(version)}.sha256', '${_hex(sha.bytes)}  Kumo-$version-windows-x64.zip\n');
    }
  }

  UpdateConfig config({String version = '0.8.2', String? key, String channel = '', bool debug = false, String exe = _installedExe}) =>
      UpdateConfig(version: version, repo: _repo, key: key ?? this.key, channel: channel, debug: debug, exe: exe, localAppData: _localAppData, updatesDir: dir.path);

  WindowsUpdates updates({UpdateConfig? config}) => WindowsUpdates(
        config: config ?? this.config(),
        http: http,
        launcher: launcher,
        timer: timers.call,
        now: () => now,
        extract: (zip, into) async {
          final text = await File(zip).readAsString();
          extracted.add((zip, text));
          await Directory('$into/Kumo').create(recursive: true);
          await File('$into/Kumo/Kumo.exe').writeAsString(text);
          await File('$into/Kumo/install.ps1').writeAsString('# install');
        },
        exeVersion: (exe) async => exeVersion(await File(exe).readAsString()),
        stopDaemon: () async => calls.add('stop kumod'),
        relaunchApp: () async {
          calls.add('relaunch');
          return true;
        },
        autoUpdate: () => auto,
        listenForExit: false,
      );
}

String _hex(List<int> bytes) => [for (final b in bytes) b.toRadixString(16).padLeft(2, '0')].join();

void main() {
  late _World w;
  setUp(() async => w = await _World.make());
  tearDown(() async {
    try {
      await w.dir.delete(recursive: true);
    } on FileSystemException {
      // A Windows file still open: the temp folder gets it later.
    }
  });

  group('versions', () {
    test('compare numerically, not as text', () {
      expect(UpdateVersion.parse('0.10.0').compareTo(UpdateVersion.parse('0.9.9')), greaterThan(0));
      expect(UpdateVersion.parse('1.2.3'), UpdateVersion.parse('1.2.3'));
      expect(UpdateVersion.tryParse('v1.2.3'), UpdateVersion.parse('1.2.3'));
      expect(UpdateVersion.tryParse('1.2'), isNull);
      expect(UpdateVersion.tryParse('1.2.3-beta'), isNull);
    });

    test('the feed picks the highest published Windows build, skipping drafts and prereleases', () async {
      await w.publish([
        _release('0.9.1', draft: true),
        _release('0.10.0', prerelease: true),
        _release('0.9.0'),
        _release('0.10.1', sig: false),
        _release('0.8.9'),
      ]);
      final feed = UpdateFeed(w.http, repo: _repo, userAgent: 'Kumo/0.8.2', now: () => w.now);
      final answer = await feed.latest();
      expect(answer.release?.version, UpdateVersion.parse('0.9.0'));
      expect(answer.release?.zip.toString(), _zipUrl('0.9.0'));
      final (url, headers) = w.http.gets.single;
      expect(url, _feedUrl);
      expect(headers['Accept'], 'application/vnd.github+json');
      expect(headers['User-Agent'], 'Kumo/0.8.2');
    });

    test('a zip whose name disagrees with its tag is skipped', () async {
      await w.publish([_release('0.9.0', tag: 'v0.9.1')]);
      final answer = await UpdateFeed(w.http, repo: _repo, userAgent: 'Kumo', now: () => w.now).latest();
      expect(answer.release, isNull);
    });

    test('the feed asks with its ETag and a 304 keeps the last answer', () async {
      await w.publish([_release('0.9.0')], headers: {'etag': '"abc"'});
      final feed = UpdateFeed(w.http, repo: _repo, userAgent: 'Kumo', now: () => w.now);
      expect((await feed.latest()).release?.version, UpdateVersion.parse('0.9.0'));
      w.http.replies[_feedUrl] = const HttpReply(304, {}, []);
      final again = await feed.latest();
      expect(w.http.gets.last.$2['If-None-Match'], '"abc"');
      expect(again.release?.version, UpdateVersion.parse('0.9.0'));
    });

    test('a rate limit backs off until GitHub says it resets', () async {
      final reset = w.now.add(const Duration(minutes: 20));
      w.http.replies[_feedUrl] = HttpReply(403, {'x-ratelimit-remaining': '0', 'x-ratelimit-reset': '${reset.millisecondsSinceEpoch ~/ 1000}'}, const []);
      final feed = UpdateFeed(w.http, repo: _repo, userAgent: 'Kumo', now: () => w.now);
      final answer = await feed.latest();
      expect(answer.release, isNull);
      expect(answer.retryAt, reset);
      await feed.latest();
      expect(w.http.feedGets(), 1, reason: 'not asked again before the reset');
      w.now = reset.add(const Duration(seconds: 1));
      await w.publish([_release('0.9.0')]);
      expect((await feed.latest()).release?.version, UpdateVersion.parse('0.9.0'));
    });
  });

  group('checking', () {
    test('a newer signed release downloads, extracts and is ready', () async {
      await w.publish([_release('0.9.0')]);
      final updates = w.updates();
      var notified = 0;
      updates.addListener(() => notified++);
      expect(updates.canCheck, isTrue);
      await updates.check();
      expect(updates.ready, '0.9.0');
      expect(updates.status.value, isA<UpdateReady>().having((s) => s.version, 'version', '0.9.0'));
      expect(notified, greaterThan(0));
      final kumo = updates.readyDir!;
      final folder = Directory(kumo).parent.path;
      expect(w.folders().single, startsWith('0.9.0.4242.'), reason: 'this Kumo’s own folder');
      expect(File('$kumo\\install.ps1').existsSync(), isTrue);
      expect(File('$folder\\Kumo.zip').existsSync(), isTrue);
      expect(File('$folder\\Kumo.zip.part').existsSync(), isFalse);
      updates.dispose();
    });

    test('a signature by another key, or none, never makes it ready', () async {
      await w.publish([_release('0.9.0')]);
      final other = await Ed25519().newKeyPair();
      final forged = await Ed25519().sign(utf8.encode('zip of Kumo 0.9.0'), keyPair: other);
      w.http.text('${_zipUrl('0.9.0')}.sig', base64.encode(forged.bytes));
      final updates = w.updates();
      await updates.check();
      expect(updates.ready, isNull);
      expect(updates.status.value, isA<UpdateFailed>());
      expect(w.folders(), isEmpty, reason: 'thrown away');

      w.http.replies.remove('${_zipUrl('0.9.0')}.sig');
      await updates.check();
      expect(updates.ready, isNull);
      expect(updates.status.value, isA<UpdateFailed>());

      w.http.text('${_zipUrl('0.9.0')}.sig', 'not base64!');
      await updates.check();
      expect(updates.ready, isNull);
      updates.dispose();
    });

    test('a zip that does not match its .sha256 is not ready', () async {
      await w.publish([_release('0.9.0')]);
      w.http.text('${_zipUrl('0.9.0')}.sha256', '${'0' * 64}\n');
      final updates = w.updates();
      await updates.check();
      expect(updates.ready, isNull);
      expect(updates.status.value, isA<UpdateFailed>());
      updates.dispose();
    });

    test('extracts the bytes it verified, from its own folder, never a shared one', () async {
      await w.publish([_release('0.9.0')]);
      // Someone's zip where every Kumo used to download, swapped in again
      // while this one downloads.
      final shared = File('${w.dir.path}\\0.9.0\\Kumo.zip');
      await shared.create(recursive: true);
      await shared.writeAsString('evil zip 0.9.0');
      File? downloaded;
      w.http.afterDownload = (to) {
        downloaded = to;
        shared
          ..createSync(recursive: true)
          ..writeAsStringSync('evil zip 0.9.0');
      };
      final updates = w.updates();
      await updates.check();
      expect(updates.ready, '0.9.0');
      final (zip, text) = w.extracted.single;
      expect(text, 'zip of Kumo 0.9.0', reason: 'the signed bytes');
      expect(zip, isNot(shared.path));
      expect(zip, isNot(downloaded!.path), reason: 'written from the verified bytes, not read again');
      expect(File(zip).parent.path, Directory(updates.readyDir!).parent.path);
      expect(shared.readAsStringSync(), 'evil zip 0.9.0', reason: 'never touched');
      updates.dispose();
    });

    test('the same or an older version is up to date', () async {
      await w.publish([_release('0.8.2'), _release('0.8.1')]);
      final updates = w.updates();
      await updates.check();
      expect(updates.ready, isNull);
      expect(updates.status.value, isA<UpdateUpToDate>());
      expect(w.http.downloads, isEmpty);
      updates.dispose();
    });

    test('a zip whose Kumo.exe is another version than published is not ready', () async {
      await w.publish([_release('0.9.0')]);
      w.exeVersion = (_) => '0.8.0+12';
      final updates = w.updates();
      await updates.check();
      expect(updates.ready, isNull);
      expect(updates.status.value, isA<UpdateFailed>());
      expect(w.folders(), isEmpty);
      updates.dispose();
    });

    test('checks 30 s after start, then hourly; turned off, only by hand', () async {
      await w.publish([_release('0.8.2')]);
      final updates = w.updates();
      expect(w.timers.delays, [const Duration(seconds: 30)]);
      w.timers.fire();
      await updates.settled;
      expect(w.http.feedGets(), 1);
      expect(w.timers.delays, [const Duration(hours: 1)]);

      w.auto = false;
      w.timers.fire();
      await updates.settled;
      expect(w.http.feedGets(), 1, reason: 'automatic checks are off');
      expect(w.timers.delays, [const Duration(hours: 1)], reason: 'still scheduled, for when they are on again');

      await updates.check();
      expect(w.http.feedGets(), 2, reason: 'a manual check always works');
      updates.dispose();
      expect(w.timers.delays, isEmpty);
    });

    test('a rate-limited manual check says so', () async {
      final reset = w.now.add(const Duration(minutes: 20));
      w.http.replies[_feedUrl] = HttpReply(429, {'x-ratelimit-reset': '${reset.millisecondsSinceEpoch ~/ 1000}'}, const []);
      final updates = w.updates();
      await updates.check();
      expect(updates.status.value, isA<UpdateFailed>().having((s) => s.message, 'message', contains('rate limit')));
      updates.dispose();
    });
  });

  group('off', () {
    Future<void> expectOff(UpdateConfig config) async {
      final updates = w.updates(config: config);
      expect(updates.canCheck, isFalse);
      expect(w.timers.pending, isEmpty);
      await updates.check();
      expect(w.http.gets, isEmpty);
      updates.dispose();
    }

    test('in debug builds', () => expectOff(w.config(debug: true)));
    test('without a version, repo or key', () async {
      await expectOff(w.config(version: ''));
      await expectOff(UpdateConfig(version: '0.8.2', repo: '', key: w.key, exe: _installedExe, localAppData: _localAppData, updatesDir: w.dir.path));
      await expectOff(w.config(key: ''));
    });
    test('on a channel build', () => expectOff(w.config(channel: 'beta')));
    test('when this Kumo is not the installed one', () async {
      await expectOff(w.config(exe: r'C:\src\kumo\kumo-ui\build\windows\x64\runner\Release\Kumo.exe'));
      await expectOff(w.config(exe: r'C:\Users\me\AppData\Local\Programs\KumoOld\Kumo.exe'));
    });
    test('the installed one is matched in any case and either slash', () {
      expect(w.config(exe: r'c:\users\ME\appdata\local\programs\kumo\Kumo.exe').active, isTrue);
      expect(w.config(exe: 'C:/Users/me/AppData/Local/Programs/Kumo/Kumo.exe').active, isTrue);
    });
  });

  group('installing', () {
    Future<WindowsUpdates> readyUpdates() async {
      await w.publish([_release('0.9.0')]);
      final updates = w.updates();
      await updates.check();
      expect(updates.ready, '0.9.0');
      return updates;
    }

    test('restart stops kumod, starts the zip installer for this pid, then exits', () async {
      final updates = await readyUpdates();
      await updates.installAndRelaunch();
      expect(w.calls, ['stop kumod', 'start', 'exit 0']);
      final (exe, args) = w.launcher.started.single;
      expect(exe.toLowerCase(), endsWith('powershell.exe'));
      final kumo = updates.readyDir!;
      expect(kumo, startsWith('${w.dir.path}\\0.9.0.4242.'));
      expect(args, ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', '$kumo\\install.ps1', '-From', kumo, '-WaitPid', '4242']);
      updates.dispose();
    });

    test('relaunch with an update ready installs it too', () async {
      final updates = await readyUpdates();
      await updates.relaunch();
      expect(w.calls, ['stop kumod', 'start', 'exit 0']);
      updates.dispose();
    });

    test('relaunch with none ready just relaunches', () async {
      final updates = w.updates();
      await updates.relaunch();
      expect(w.calls, ['stop kumod', 'relaunch']);
      updates.dispose();
    });

    test('an installer that will not start still relaunches Kumo', () async {
      final updates = await readyUpdates();
      w.launcher.fail = true;
      await updates.installAndRelaunch();
      expect(w.calls, ['stop kumod', 'relaunch']);
      updates.dispose();
    });

    test('an installer gone missing does not quit, says so and downloads again', () async {
      final updates = await readyUpdates();
      await File('${updates.readyDir}\\install.ps1').delete();
      await updates.installAndRelaunch();
      expect(w.calls, ['stop kumod'], reason: 'Kumo keeps running');
      expect(w.launcher.started, isEmpty);
      expect(updates.status.value, isA<UpdateFailed>());
      expect(updates.ready, isNull);
      expect(updates.readyDir, isNull);

      await updates.check();
      expect(w.http.downloads, hasLength(2));
      expect(updates.ready, '0.9.0');
      updates.dispose();
    });

    test('quitting with its installer gone missing starts nothing', () async {
      final updates = await readyUpdates();
      await File('${updates.readyDir}\\install.ps1').delete();
      expect(await updates.installOnQuit(), AppExitResponse.exit);
      expect(w.calls, isEmpty);
      updates.dispose();
    });

    test('quitting with an update ready installs it without reopening Kumo', () async {
      final updates = await readyUpdates();
      expect(await updates.installOnQuit(), AppExitResponse.exit);
      expect(w.calls, ['start'], reason: 'kumod keeps running, as on macOS');
      expect(w.launcher.started.single.$2, containsAllInOrder(['-WaitPid', '4242', '-NoRelaunch']));
      updates.dispose();
    });

    test('quitting with none ready just quits', () async {
      final updates = w.updates();
      expect(await updates.installOnQuit(), AppExitResponse.exit);
      expect(w.calls, isEmpty);
      updates.dispose();
    });
  });

  group('startup', () {
    test('cleans up the last downloads and reports a failed install once', () async {
      await Directory('${w.dir.path}/0.8.2/Kumo').create(recursive: true);
      await File('${w.dir.path}/update.log').writeAsString('2026-11-18 10:00:00 Installing Kumo from x\n'
          "2026-11-18 10:00:05 Kumo wasn't updated: Access denied\n");
      var updates = w.updates();
      await updates.settled;
      expect(updates.status.value, isA<UpdateFailed>().having((s) => s.message, 'message', contains('Access denied')));
      expect(Directory('${w.dir.path}/0.8.2').existsSync(), isFalse);
      expect(File('${w.dir.path}/update.log').existsSync(), isTrue, reason: 'the log stays');
      updates.dispose();

      updates = w.updates();
      await updates.settled;
      expect(updates.status.value, isA<UpdateIdle>(), reason: 'reported already');
      updates.dispose();
    });

    test('cleanup leaves the update another running Kumo holds', () async {
      await w.publish([_release('0.9.0')]);
      final other = w.updates();
      await other.check();
      final held = other.readyDir!;
      await Directory('${w.dir.path}/0.8.2/Kumo').create(recursive: true);

      final updates = w.updates();
      await updates.settled;
      expect(File('$held\\install.ps1').existsSync(), isTrue, reason: 'still in use');
      expect(File('$held\\Kumo.exe').existsSync(), isTrue);
      expect(Directory('${w.dir.path}/0.8.2').existsSync(), isFalse, reason: 'no one holds it');
      updates.dispose();
      other.dispose();
    });

    test('a successful last install reports nothing', () async {
      await File('${w.dir.path}/update.log').writeAsString('2026-11-18 10:00:05 Kumo is in C:\\x (and in the Start menu)\n');
      final updates = w.updates();
      await updates.settled;
      expect(updates.status.value, isA<UpdateIdle>());
      updates.dispose();
    });
  });

  group('Kumo.exe version', () {
    Uint8List utf16(String s) {
      final b = BytesBuilder();
      for (final unit in s.codeUnits) {
        b.add([unit & 0xff, unit >> 8]);
      }
      return b.toBytes();
    }

    test('reads ProductVersion from the version resource', () {
      final bytes = BytesBuilder()
        ..add(List.filled(37, 7))
        ..add(utf16('FileVersion\u0000'))
        ..add([0, 0])
        ..add(utf16('0.0.1+1\u0000'))
        ..add(utf16('ProductVersion\u0000'))
        ..add([0, 0])
        ..add(utf16('0.9.0+77\u0000'))
        ..add(List.filled(11, 3));
      expect(productVersionIn(bytes.toBytes()), '0.9.0+77');
    });

    test('none there is null', () {
      expect(productVersionIn(Uint8List.fromList(List.filled(64, 1))), isNull);
    });
  });
}
