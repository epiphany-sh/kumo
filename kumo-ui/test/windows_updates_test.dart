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

/// The updater's files live on the disk running the tests, any OS.
final _sep = Platform.pathSeparator;

String _zipUrl(String v) => 'https://github.com/$_repo/releases/download/v$v/Kumo-$v-windows-x64.zip';
String _setupUrl(String v) => 'https://github.com/$_repo/releases/download/v$v/Kumo-$v-windows-x64-setup.exe';

/// A release as GitHub's API lists it.
Map<String, Object?> _release(String version, {bool draft = false, bool prerelease = false, bool sig = true, bool sha = true, bool setup = true, String? tag}) => {
      'tag_name': tag ?? 'v$version',
      'draft': draft,
      'prerelease': prerelease,
      'assets': [
        {'name': 'Kumo-$version.dmg', 'browser_download_url': 'https://github.com/$_repo/releases/download/v$version/Kumo-$version.dmg'},
        {'name': 'Kumo-$version-windows-x64.zip', 'browser_download_url': _zipUrl(version)},
        {'name': 'Kumo-$version-windows-x64.zip.sig', 'browser_download_url': '${_zipUrl(version)}.sig'},
        if (setup) {'name': 'Kumo-$version-windows-x64-setup.exe', 'browser_download_url': _setupUrl(version)},
        if (setup && sig) {'name': 'Kumo-$version-windows-x64-setup.exe.sig', 'browser_download_url': '${_setupUrl(version)}.sig'},
        if (setup && sha) {'name': 'Kumo-$version-windows-x64-setup.exe.sha256', 'browser_download_url': '${_setupUrl(version)}.sha256'},
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

/// A signed release, its installer and its feed, and an updater to check it.
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

  /// The update folders' names in [dir].
  List<String> folders() => [for (final e in dir.listSync()) if (e is Directory) e.uri.pathSegments.lastWhere((s) => s.isNotEmpty)];

  /// What the setup.exe says it is, by its content.
  String Function(String setupText) exeVersion = (setup) => setup.split(' ').last;

  String get key => base64.encode(publicKey.bytes);

  /// The download folders an updater holds. Windows locks a file per open
  /// handle, so a second updater in this process is refused as another
  /// Kumo would be; POSIX locks are per process and never refuse it.
  final held = <String>{};

  void Function()? lockFolder(String dir) {
    if (held.contains(dir)) return null;
    final release = lockUpdateFolder(dir);
    if (release == null) return null;
    held.add(dir);
    return () {
      held.remove(dir);
      release();
    };
  }

  /// Publishes [releases]; each version's setup.exe is signed (and hashed)
  /// unless told otherwise.
  Future<void> publish(List<Map<String, Object?>> releases, {Map<String, String> headers = const {}}) async {
    http.json(_feedUrl, releases, headers: headers);
    for (final r in releases) {
      final version = (r['tag_name']! as String).replaceFirst('v', '');
      final setup = utf8.encode('setup of Kumo $version');
      http.bytes(_setupUrl(version), setup);
      final sig = await Ed25519().sign(setup, keyPair: keyPair);
      http.text('${_setupUrl(version)}.sig', base64.encode(sig.bytes));
      final sha = await Sha256().hash(setup);
      http.text('${_setupUrl(version)}.sha256', '${_hex(sha.bytes)}  Kumo-$version-windows-x64-setup.exe\n');
      // The zip, signed too, for the updater of Kumo 0.9.0 and older.
      final zip = utf8.encode('zip of Kumo $version');
      http.bytes(_zipUrl(version), zip);
      http.text('${_zipUrl(version)}.sig', base64.encode((await Ed25519().sign(zip, keyPair: keyPair)).bytes));
    }
  }

  UpdateConfig config({String version = '0.8.2', String? key, String channel = '', bool debug = false, String exe = _installedExe, String feed = '', bool prereleases = false}) => UpdateConfig(
      version: version,
      repo: _repo,
      key: key ?? this.key,
      channel: channel,
      debug: debug,
      exe: exe,
      localAppData: _localAppData,
      updatesDir: dir.path,
      feed: feed,
      prereleases: prereleases);

  WindowsUpdates updates({UpdateConfig? config}) => WindowsUpdates(
        config: config ?? this.config(),
        http: http,
        launcher: launcher,
        timer: timers.call,
        now: () => now,
        exeVersion: (exe) async => exeVersion(await File(exe).readAsString()),
        stopDaemon: () async => calls.add('stop kumod'),
        relaunchApp: () async {
          calls.add('relaunch');
          return true;
        },
        autoUpdate: () => auto,
        lockFolder: lockFolder,
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
      expect(UpdateVersion.tryParse('1.2.3-'), isNull);
      expect(UpdateVersion.tryParse('1.2.3-beta..1'), isNull);
    });

    test('prereleases order as semver: before their release, identifiers one by one', () {
      final ordered = ['0.9.9', '0.10.0-1', '0.10.0-alpha', '0.10.0-beta.1', '0.10.0-beta.2', '0.10.0-beta.10', '0.10.0-rc.1', '0.10.0', '0.10.1-beta.1'];
      final versions = [for (final v in ordered) UpdateVersion.parse(v)];
      for (var i = 0; i + 1 < versions.length; i++) {
        expect(versions[i + 1] > versions[i], isTrue, reason: '${versions[i + 1]} > ${versions[i]}');
      }
      expect(UpdateVersion.parse('v0.10.0-beta.1').toString(), '0.10.0-beta.1');
      expect(UpdateVersion.parse('0.10.0-beta.1').isPrerelease, isTrue);
      expect(UpdateVersion.parse('0.10.0').isPrerelease, isFalse);
      expect(UpdateVersion.parse('0.10.0-beta.1'), isNot(UpdateVersion.parse('0.10.0')));
    });

    test('prereleases are skipped unless the build opts in', () async {
      await w.publish([_release('0.10.0-beta.2', prerelease: true), _release('0.10.0-beta.1'), _release('0.9.0')]);
      final stable = await UpdateFeed(w.http, repo: _repo, userAgent: 'Kumo', now: () => w.now).latest();
      expect(stable.release?.version, UpdateVersion.parse('0.9.0'), reason: 'neither GitHub prereleases nor -beta versions');
      final beta = await UpdateFeed(w.http, repo: _repo, userAgent: 'Kumo', now: () => w.now, prereleases: true).latest();
      expect(beta.release?.version, UpdateVersion.parse('0.10.0-beta.2'));
      expect(beta.release?.installer.toString(), _setupUrl('0.10.0-beta.2'));
    });

    test('a build can read its releases from another feed (testing a beta)', () async {
      const feed = 'http://127.0.0.1:8765/releases.json';
      w.http.json(feed, [_release('0.10.0-beta.2', prerelease: true)]);
      final updates = w.updates(config: w.config(version: '0.10.0-beta.1', feed: feed, prereleases: true));
      expect(updates.canCheck, isTrue);
      await updates.check();
      expect(w.http.gets.first.$1, feed);
      expect(w.http.feedGets(), 0, reason: 'GitHub is not asked');
      updates.dispose();
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
      expect(answer.release?.installer.toString(), _setupUrl('0.9.0'));
      final (url, headers) = w.http.gets.single;
      expect(url, _feedUrl);
      expect(headers['Accept'], 'application/vnd.github+json');
      expect(headers['User-Agent'], 'Kumo/0.8.2');
    });

    test('a release with only the zip (no setup.exe) is skipped', () async {
      await w.publish([_release('0.9.1', setup: false), _release('0.9.0')]);
      final answer = await UpdateFeed(w.http, repo: _repo, userAgent: 'Kumo', now: () => w.now).latest();
      expect(answer.release?.version, UpdateVersion.parse('0.9.0'));
    });

    test('a setup.exe whose name disagrees with its tag is skipped', () async {
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
    test('a newer signed release downloads and is ready', () async {
      await w.publish([_release('0.9.0')]);
      final updates = w.updates();
      var notified = 0;
      updates.addListener(() => notified++);
      expect(updates.canCheck, isTrue);
      await updates.check();
      expect(updates.ready, '0.9.0');
      expect(updates.status.value, isA<UpdateReady>().having((s) => s.version, 'version', '0.9.0'));
      expect(notified, greaterThan(0));
      final setup = updates.readyInstaller!;
      final folder = File(setup).parent.path;
      expect(w.folders().single, startsWith('0.9.0.4242.'), reason: 'this Kumo’s own folder');
      expect(setup, endsWith('${_sep}Kumo-0.9.0-windows-x64-setup.exe'));
      expect(File(setup).readAsStringSync(), 'setup of Kumo 0.9.0');
      expect(File('$folder${_sep}Kumo-0.9.0-windows-x64-setup.exe.part').existsSync(), isFalse);
      updates.dispose();
    });

    test('a signature by another key, or none, never makes it ready', () async {
      await w.publish([_release('0.9.0')]);
      final other = await Ed25519().newKeyPair();
      final forged = await Ed25519().sign(utf8.encode('setup of Kumo 0.9.0'), keyPair: other);
      w.http.text('${_setupUrl('0.9.0')}.sig', base64.encode(forged.bytes));
      final updates = w.updates();
      await updates.check();
      expect(updates.ready, isNull);
      expect(updates.status.value, isA<UpdateFailed>());
      expect(w.folders(), isEmpty, reason: 'thrown away');

      w.http.replies.remove('${_setupUrl('0.9.0')}.sig');
      await updates.check();
      expect(updates.ready, isNull);
      expect(updates.status.value, isA<UpdateFailed>());

      w.http.text('${_setupUrl('0.9.0')}.sig', 'not base64!');
      await updates.check();
      expect(updates.ready, isNull);
      updates.dispose();
    });

    test('a setup.exe that does not match its .sha256 is not ready', () async {
      await w.publish([_release('0.9.0')]);
      w.http.text('${_setupUrl('0.9.0')}.sha256', '${'0' * 64}\n');
      final updates = w.updates();
      await updates.check();
      expect(updates.ready, isNull);
      expect(updates.status.value, isA<UpdateFailed>());
      updates.dispose();
    });

    test('keeps the bytes it verified, in its own folder, never a shared one', () async {
      await w.publish([_release('0.9.0')]);
      // Someone's setup.exe where every Kumo could download it: never what runs.
      final shared = File('${w.dir.path}${_sep}0.9.0${_sep}Kumo-0.9.0-windows-x64-setup.exe');
      await shared.create(recursive: true);
      await shared.writeAsString('evil setup 0.9.0');
      File? downloaded;
      w.http.afterDownload = (to) {
        downloaded = to;
        // Startup cleaned the folder up; it's back while this one downloads.
        shared
          ..createSync(recursive: true)
          ..writeAsStringSync('evil setup 0.9.0');
      };
      final updates = w.updates();
      await updates.check();
      expect(updates.ready, '0.9.0');
      final setup = updates.readyInstaller!;
      expect(File(setup).readAsStringSync(), 'setup of Kumo 0.9.0', reason: 'the signed bytes');
      expect(setup, isNot(shared.path));
      expect(setup, isNot(downloaded!.path), reason: 'written from the verified bytes, not the download renamed');
      expect(shared.readAsStringSync(), 'evil setup 0.9.0', reason: 'never touched');
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

    test('a setup.exe that says it is another version than published is not ready', () async {
      await w.publish([_release('0.9.0')]);
      w.exeVersion = (_) => '0.8.0';
      final updates = w.updates();
      await updates.check();
      expect(updates.ready, isNull);
      expect(updates.status.value, isA<UpdateFailed>());
      expect(w.folders(), isEmpty);
      updates.dispose();
    });

    test('a check asked again while one runs shares it: one feed request, one download', () async {
      await w.publish([_release('0.9.0')]);
      final updates = w.updates();
      final first = updates.check();
      final second = updates.check();
      await Future.wait([first, second]);
      expect(w.http.feedGets(), 1);
      expect(w.http.downloads, [_setupUrl('0.9.0')]);
      expect(updates.ready, '0.9.0');
      await updates.check();
      expect(w.http.feedGets(), 2, reason: 'a later check asks again');
      expect(w.http.downloads, hasLength(1), reason: 'the version ready is not downloaded again');
      updates.dispose();
    });

    test('a manual check runs now, without waiting for the timer', () async {
      await w.publish([_release('0.9.0')]);
      final updates = w.updates();
      expect(w.timers.delays, [const Duration(seconds: 30)], reason: 'the first automatic check is still to come');
      await updates.check();
      expect(w.http.feedGets(), 1);
      expect(updates.status.value, isA<UpdateReady>());
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
    test('a beta build updates itself too', () {
      expect(w.config(version: '0.10.0-beta.1').active, isTrue);
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

    test('restart stops kumod, starts the setup silently for this pid, then exits', () async {
      final updates = await readyUpdates();
      await updates.installAndRelaunch();
      expect(w.calls, ['stop kumod', 'start', 'exit 0']);
      final (exe, args) = w.launcher.started.single;
      expect(exe, updates.readyInstaller);
      expect(exe, startsWith('${w.dir.path}${_sep}0.9.0.4242.'));
      expect(args, ['/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/WAITPID=4242', '/LOG=${w.dir.path}${_sep}setup.log', '/RELAUNCH']);
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
      await File(updates.readyInstaller!).delete();
      await updates.installAndRelaunch();
      expect(w.calls, ['stop kumod'], reason: 'Kumo keeps running');
      expect(w.launcher.started, isEmpty);
      expect(updates.status.value, isA<UpdateFailed>());
      expect(updates.ready, isNull);
      expect(updates.readyInstaller, isNull);

      await updates.check();
      expect(w.http.downloads, hasLength(2));
      expect(updates.ready, '0.9.0');
      updates.dispose();
    });

    test('quitting with its installer gone missing starts nothing', () async {
      final updates = await readyUpdates();
      await File(updates.readyInstaller!).delete();
      expect(await updates.installOnQuit(), AppExitResponse.exit);
      expect(w.calls, isEmpty);
      updates.dispose();
    });

    test('quitting with an update ready installs it without reopening Kumo', () async {
      final updates = await readyUpdates();
      expect(await updates.installOnQuit(), AppExitResponse.exit);
      expect(w.calls, ['start'], reason: 'kumod keeps running, as on macOS');
      final args = w.launcher.started.single.$2;
      expect(args, contains('/WAITPID=4242'));
      expect(args, isNot(contains('/RELAUNCH')));
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
      final held = other.readyInstaller!;
      await Directory('${w.dir.path}/0.8.2/Kumo').create(recursive: true);

      final updates = w.updates();
      await updates.settled;
      expect(File(held).existsSync(), isTrue, reason: 'still in use');
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

  group('executable version', () {
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

    test('only the PE image counts, not data appended to it (a setup.exe’s payload)', () {
      // A minimal PE: the DOS header points at "PE\0\0", whose one section
      // is 0x40 bytes at 0x100; after it, an overlay as Inno Setup appends.
      final image = Uint8List(0x140);
      final view = ByteData.sublistView(image);
      image[0] = 0x4d; // MZ
      image[1] = 0x5a;
      view.setUint32(0x3c, 0x80, Endian.little);
      image.setAll(0x80, [0x50, 0x45, 0, 0]);
      view.setUint16(0x80 + 4 + 2, 1, Endian.little); // NumberOfSections
      view.setUint16(0x80 + 4 + 16, 0, Endian.little); // SizeOfOptionalHeader
      const section = 0x80 + 4 + 20;
      view.setUint32(section + 16, 0x40, Endian.little); // SizeOfRawData
      view.setUint32(section + 20, 0x100, Endian.little); // PointerToRawData
      image.setAll(0x100, [...utf16('ProductVersion\u0000'), ...utf16('0.9.0\u0000')]);
      final bytes = BytesBuilder()
        ..add(image)
        ..add(utf16('ProductVersion\u0000'))
        ..add(utf16('6.4.3\u0000'));
      expect(productVersionIn(bytes.toBytes()), '0.9.0');
    });

    test('none there is null', () {
      expect(productVersionIn(Uint8List.fromList(List.filled(64, 1))), isNull);
    });
  });
}
