import 'dart:async';
import 'dart:convert';
import 'dart:io' as io show exit, pid;
import 'dart:io';
import 'dart:isolate';
import 'dart:math' show Random;
import 'dart:typed_data';
import 'dart:ui' show AppExitResponse;

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;

import 'channel.dart';
import 'os/host_os.dart';
import 'updates.dart';

/// A release version, X.Y.Z, compared number by number.
@immutable
class UpdateVersion implements Comparable<UpdateVersion> {
  const UpdateVersion(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  static final _pattern = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)$');

  /// `X.Y.Z` or `vX.Y.Z`; null for anything else (`1.2`, `1.2.3-beta`).
  static UpdateVersion? tryParse(String text) {
    final m = _pattern.firstMatch(text.trim());
    if (m == null) return null;
    return UpdateVersion(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }

  static UpdateVersion parse(String text) => tryParse(text) ?? (throw FormatException('Not a version: $text'));

  @override
  int compareTo(UpdateVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator >(UpdateVersion other) => compareTo(other) > 0;
  bool operator <=(UpdateVersion other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) => other is UpdateVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}

/// What this build of Kumo is and where it runs: whether it updates itself.
class UpdateConfig {
  const UpdateConfig({
    required this.version,
    required this.repo,
    required this.key,
    this.channel = '',
    this.debug = false,
    required this.exe,
    required this.localAppData,
    this.systemRoot = r'C:\Windows',
    String? updatesDir,
  }) : _updatesDir = updatesDir;

  /// This build's, from `packaging/windows-zip.sh` (`--dart-define`).
  factory UpdateConfig.fromEnvironment(Map<String, String> env) => UpdateConfig(
        version: const String.fromEnvironment('KUMO_VERSION'),
        repo: const String.fromEnvironment('KUMO_RELEASE_REPO'),
        key: const String.fromEnvironment('KUMO_UPDATE_KEY'),
        channel: kumoChannel,
        debug: kDebugMode,
        exe: Platform.resolvedExecutable,
        localAppData: env['LOCALAPPDATA'] ?? '',
        systemRoot: env['SystemRoot'] ?? env['SYSTEMROOT'] ?? r'C:\Windows',
      );

  /// X.Y.Z.
  final String version;

  /// owner/name on GitHub.
  final String repo;

  /// Base64 of the 32-byte ed25519 public key the `.sig` is checked with.
  final String key;

  /// `KUMO_CHANNEL`: a beta or sandbox build never takes a release.
  final String channel;
  final bool debug;

  /// The running Kumo.exe.
  final String exe;
  final String localAppData;
  final String systemRoot;
  final String? _updatesDir;

  /// Where `install.ps1` puts Kumo (its default `-Dest`).
  String get installDir => '$localAppData\\Programs\\Kumo';

  /// Downloads, one folder per version, and `install.ps1`'s `update.log`.
  String get updatesDir => _updatesDir ?? '$localAppData\\Kumo\\updates';

  /// Windows PowerShell, which every Windows has.
  String get powershell => '$systemRoot\\System32\\WindowsPowerShell\\v1.0\\powershell.exe';

  /// Windows' own bsdtar, which extracts zips.
  String get tar => '$systemRoot\\System32\\tar.exe';

  /// The public key's bytes, or null when [key] isn't one.
  Uint8List? get publicKey {
    try {
      final bytes = base64.decode(key.trim());
      return bytes.length == 32 ? bytes : null;
    } on FormatException {
      return null;
    }
  }

  /// A release build with all it needs, running from where `install.ps1`
  /// installed it: never a build folder, which an update would replace.
  bool get active =>
      !debug &&
      channel.isEmpty &&
      UpdateVersion.tryParse(version) != null &&
      repo.isNotEmpty &&
      publicKey != null &&
      localAppData.isNotEmpty &&
      _normal(exe).startsWith('${_normal(installDir)}\\');

  static String _normal(String path) => path.replaceAll('/', r'\').toLowerCase();
}

/// An HTTP answer: [headers] by lowercase name.
class HttpReply {
  const HttpReply(this.status, this.headers, this.body);
  final int status;
  final Map<String, String> headers;
  final List<int> body;

  String get text => utf8.decode(body, allowMalformed: true);
}

/// The network, as the updater uses it (injectable for tests).
abstract interface class UpdateHttp {
  /// A small answer (the feed, a .sig, a .sha256), whatever its status.
  Future<HttpReply> get(Uri url, {Map<String, String> headers = const {}});

  /// Writes [url] to [to]; throws unless it all arrived.
  Future<void> download(Uri url, File to);
}

/// [UpdateHttp] over `dart:io`.
class IoUpdateHttp implements UpdateHttp {
  IoUpdateHttp({required this.userAgent});

  final String userAgent;
  late final _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 30)
    ..userAgent = userAgent;

  @override
  Future<HttpReply> get(Uri url, {Map<String, String> headers = const {}}) async {
    final request = await _client.getUrl(url);
    headers.forEach(request.headers.set);
    final response = await request.close().timeout(const Duration(seconds: 60));
    final body = await response.fold<BytesBuilder>(BytesBuilder(copy: false), (b, chunk) => b..add(chunk)).timeout(const Duration(seconds: 60));
    final names = <String, String>{};
    response.headers.forEach((name, values) => names[name.toLowerCase()] = values.join(','));
    return HttpReply(response.statusCode, names, body.takeBytes());
  }

  @override
  Future<void> download(Uri url, File to) async {
    final request = await _client.getUrl(url);
    final response = await request.close().timeout(const Duration(seconds: 60));
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw HttpException('GitHub answered ${response.statusCode}', uri: url);
    }
    final sink = to.openWrite();
    try {
      await response.timeout(const Duration(seconds: 60)).pipe(sink);
    } finally {
      await sink.close();
    }
    final expected = response.contentLength;
    if (expected >= 0 && await to.length() != expected) throw HttpException('The download was cut short', uri: url);
  }
}

/// A Windows build on GitHub: its zip, signature and checksum.
class FeedRelease {
  const FeedRelease(this.version, this.zip, this.sig, this.sha256);
  final UpdateVersion version;
  final Uri zip;
  final Uri sig;

  /// The `.sha256`, when the release has one.
  final Uri? sha256;
}

/// What the feed said: the newest [release] (null: none), or to wait until
/// [retryAt] (GitHub's rate limit).
class FeedAnswer {
  const FeedAnswer({this.release, this.retryAt});
  final FeedRelease? release;
  final DateTime? retryAt;
}

/// GitHub's releases of [repo]: the newest published one with a signed
/// Windows zip. Not "latest", which is the newest with the macOS build
/// (`docs/releasing.md`).
class UpdateFeed {
  UpdateFeed(this.http, {required this.repo, required this.userAgent, required this.now});

  final UpdateHttp http;
  final String repo;
  final String userAgent;
  final DateTime Function() now;

  String? _etag;
  FeedRelease? _last;
  DateTime? _retryAt;

  Uri get url => Uri.parse('https://api.github.com/repos/$repo/releases?per_page=20');

  static final _zipName = RegExp(r'^Kumo-(\d+\.\d+\.\d+)-windows-x64\.zip$');

  /// Asks GitHub, unless its rate limit says to wait; an unchanged list
  /// (304, by ETag) costs nothing and keeps the last answer. Throws on
  /// anything else GitHub answers.
  Future<FeedAnswer> latest() async {
    final wait = _retryAt;
    if (wait != null && now().isBefore(wait)) return FeedAnswer(retryAt: wait);
    _retryAt = null;
    final etag = _etag;
    final reply = await http.get(url, headers: {
      'Accept': 'application/vnd.github+json',
      'User-Agent': userAgent,
      'X-GitHub-Api-Version': '2022-11-28',
      if (etag != null) 'If-None-Match': etag,
    });
    switch (reply.status) {
      case 304:
        return FeedAnswer(release: _last);
      case 200:
        final release = newest(jsonDecode(reply.text));
        _etag = reply.headers['etag'];
        _last = release;
        return FeedAnswer(release: release);
      case 403 || 429 when reply.status == 429 || reply.headers['x-ratelimit-remaining'] == '0' || reply.headers.containsKey('retry-after'):
        final at = _resetOf(reply.headers);
        _retryAt = at;
        return FeedAnswer(retryAt: at);
      default:
        throw HttpException('GitHub answered ${reply.status}', uri: url);
    }
  }

  /// `x-ratelimit-reset` (epoch seconds), else `retry-after` (seconds),
  /// else an hour.
  DateTime _resetOf(Map<String, String> headers) {
    final reset = int.tryParse(headers['x-ratelimit-reset'] ?? '');
    if (reset != null) return DateTime.fromMillisecondsSinceEpoch(reset * 1000, isUtc: true);
    final after = int.tryParse(headers['retry-after'] ?? '');
    return now().add(Duration(seconds: after ?? 3600));
  }

  /// The highest version among [releases] (GitHub's JSON) published, not a
  /// prerelease, whose tag is its version and whose zip has a `.sig`.
  static FeedRelease? newest(Object? releases) {
    FeedRelease? best;
    if (releases is! List) return null;
    for (final r in releases) {
      if (r is! Map || r['draft'] == true || r['prerelease'] == true) continue;
      final tag = UpdateVersion.tryParse('${r['tag_name']}');
      final assets = <String, Uri>{};
      for (final a in r['assets'] is List ? r['assets'] as List : const []) {
        if (a is! Map || a['name'] is! String || a['browser_download_url'] is! String) continue;
        if (Uri.tryParse(a['browser_download_url'] as String) case final url?) assets[a['name'] as String] = url;
      }
      for (final MapEntry(key: name, value: zip) in assets.entries) {
        final version = UpdateVersion.tryParse(_zipName.firstMatch(name)?[1] ?? '');
        final sig = assets['$name.sig'];
        if (version == null || version != tag || sig == null) continue;
        if (best == null || version > best.version) best = FeedRelease(version, zip, sig, assets['$name.sha256']);
      }
    }
    return best;
  }
}

/// Starting the installer and quitting (injectable for tests).
abstract interface class UpdateLauncher {
  int get pid;

  /// Starts [exe] on its own, to outlive Kumo.
  Future<void> start(String exe, List<String> args);
  void exit(int code);
}

class _IoLauncher implements UpdateLauncher {
  const _IoLauncher();

  @override
  int get pid => io.pid;

  @override
  Future<void> start(String exe, List<String> args) => Process.start(exe, args, mode: ProcessStartMode.detached);

  @override
  void exit(int code) => io.exit(code);
}

/// Runs [run] once [after] has passed.
typedef UpdateTimer = Timer Function(Duration after, void Function() run);

/// Extracts the zip at [zip] into the folder [into].
typedef UpdateExtractor = Future<void> Function(String zip, String into);

/// The version an executable says it is (`X.Y.Z+build`), or null.
typedef ExeVersionReader = Future<String?> Function(String exe);

/// Holds the download folder [dir] for this Kumo until the function it
/// returns runs; null when another Kumo holds it.
typedef UpdateFolderLock = void Function()? Function(String dir);

/// [UpdateFolderLock] by [dir]'s `.lock`, locked exclusively. Windows
/// locks per open handle, so another Kumo (or another updater) is refused.
void Function()? lockUpdateFolder(String dir) {
  RandomAccessFile? file;
  try {
    file = File(WindowsUpdates._join(dir, '.lock')).openSync(mode: FileMode.append);
    file.lockSync(FileLock.exclusive);
    return file.closeSync;
  } on FileSystemException {
    file?.closeSync();
    return null;
  }
}

/// The `ProductVersion` in a Windows executable's version resource (UTF-16
/// strings: the key, padding, the value); null when there is none. Kumo's
/// is `flutter build --build-name` plus `+` and the build number
/// (`windows/runner/Runner.rc`).
String? productVersionIn(Uint8List bytes) {
  const key = 'ProductVersion\u0000';
  final needle = Uint8List(key.length * 2);
  for (var i = 0; i < key.length; i++) {
    needle[i * 2] = key.codeUnitAt(i) & 0xff;
    needle[i * 2 + 1] = key.codeUnitAt(i) >> 8;
  }
  // The resources come last: look from the end.
  outer:
  for (var at = bytes.length - needle.length; at >= 0; at--) {
    for (var j = 0; j < needle.length; j++) {
      if (bytes[at + j] != needle[j]) continue outer;
    }
    var i = at + needle.length;
    int unit(int i) => i + 1 < bytes.length ? bytes[i] | bytes[i + 1] << 8 : -1;
    while (unit(i) == 0) {
      i += 2;
    }
    final value = StringBuffer();
    for (var u = unit(i); u > 0 && value.length < 64; u = unit(i += 2)) {
      value.writeCharCode(u);
    }
    return value.isEmpty ? null : value.toString();
  }
  return null;
}

/// Why [zip] must not be installed, or null when [signature] (base64 of a
/// raw ed25519 signature) is [publicKey]'s over it and [sha256] (hex, when
/// given) is its hash.
Future<String?> updateProblem(Uint8List zip, {required String signature, required Uint8List publicKey, String? sha256}) async {
  final List<int> sig;
  try {
    sig = base64.decode(signature.trim());
  } on FormatException {
    return 'its signature isn’t readable';
  }
  if (sig.length != 64) return 'its signature isn’t readable';
  if (sha256 != null) {
    final expected = sha256.trim().split(RegExp(r'\s+')).first.toLowerCase();
    final actual = (await Sha256().hash(zip)).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    if (actual != expected) return 'it doesn’t match its checksum';
  }
  final ok = await Ed25519().verify(zip, signature: Signature(sig, publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519)));
  return ok ? null : 'its signature isn’t Kumo’s';
}

/// A failure said for the user.
class _UpdateError implements Exception {
  const _UpdateError(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Kumo's updater on Windows, as Sparkle is on macOS: an installed release
/// build checks GitHub 30 s after it starts and then every hour (while
/// Settings › General › "Download updates automatically" is on), downloads
/// a newer Windows zip, checks its ed25519 signature and extracts it to
/// `%LOCALAPPDATA%\Kumo\updates\<version>`. Then it's [ready]: restarting
/// runs that zip's `install.ps1`, which waits for Kumo to exit, swaps the
/// files and opens Kumo again; quitting runs it without the reopening.
///
/// Anything else (a debug or channel build, one without the `--dart-define`s
/// from `packaging/windows-zip.sh`, one run from a build folder) never
/// checks.
class WindowsUpdates extends AppUpdates {
  WindowsUpdates({
    UpdateConfig? config,
    UpdateHttp? http,
    UpdateLauncher? launcher,
    UpdateTimer? timer,
    DateTime Function()? now,
    UpdateExtractor? extract,
    ExeVersionReader? exeVersion,
    this.stopDaemon,
    Future<bool> Function()? relaunchApp,
    bool Function()? autoUpdate,
    UpdateFolderLock? lockFolder,
    bool listenForExit = true,
  })  : config = config ?? UpdateConfig.fromEnvironment(Platform.environment),
        _lockFolder = lockFolder ?? lockUpdateFolder,
        _launcher = launcher ?? const _IoLauncher(),
        _timer = timer ?? Timer.new,
        _now = now ?? DateTime.now,
        _extract = extract,
        _exeVersion = exeVersion ?? _readExeVersion,
        _relaunchApp = relaunchApp ?? (() => hostOs.relaunchAfterExit()),
        autoUpdate = autoUpdate ?? (() => true),
        _http = http {
    if (!this.config.active) return;
    _current = UpdateVersion.parse(this.config.version);
    _startup = _cleanUp();
    _schedule(firstCheck);
    if (listenForExit) _lifecycle = AppLifecycleListener(onExitRequested: installOnQuit);
  }

  static const firstCheck = Duration(seconds: 30);
  static const every = Duration(hours: 1);

  final UpdateConfig config;

  /// Runs before Kumo quits to restart: the relaunched Kumo starts the new
  /// `kumod` instead of finding the old one.
  final Future<void> Function()? stopDaemon;

  final UpdateLauncher _launcher;
  final UpdateTimer _timer;
  final DateTime Function() _now;
  final UpdateExtractor? _extract;
  final ExeVersionReader _exeVersion;
  final Future<bool> Function() _relaunchApp;
  final UpdateFolderLock _lockFolder;
  /// Settings › General › "Download updates automatically", read before
  /// each background check; a manual [check] runs anyway.
  final bool Function() autoUpdate;
  final UpdateHttp? _http;

  late final UpdateHttp _net = _http ?? IoUpdateHttp(userAgent: _userAgent);
  late final UpdateFeed _feed = UpdateFeed(_net, repo: config.repo, userAgent: _userAgent, now: _now);
  String get _userAgent => 'Kumo/${config.version} (Windows)';

  late final UpdateVersion _current;
  Future<void>? _startup;
  Future<void>? _inFlight;
  Timer? _next;
  AppLifecycleListener? _lifecycle;
  var _disposed = false;

  String? _ready;

  /// The ready version's extracted `Kumo` folder.
  String? _readyDir;

  @override
  String? get ready => _ready;

  /// The ready version's `Kumo` folder, in this Kumo's own download folder.
  @visibleForTesting
  String? get readyDir => _readyDir;

  @override
  bool get canCheck => config.active;

  /// Done when what started (startup, a check) has.
  @visibleForTesting
  Future<void> get settled => Future.wait([if (_startup case final f?) f, if (_inFlight case final f?) f]);

  void _set(UpdateStatus value) {
    if (!_disposed) setStatus(value);
  }

  void _schedule(Duration after) {
    _next?.cancel();
    _next = _timer(after, () {
      if (_disposed) return;
      _schedule(every);
      _check(manual: false).ignore();
    });
  }

  @override
  Future<void> check() => _check(manual: true);

  /// One check at a time: asked again meanwhile, the one running answers.
  Future<void> _check({required bool manual}) {
    if (!config.active || _disposed) return Future.value();
    return _inFlight ??= _run(manual: manual).whenComplete(() => _inFlight = null);
  }

  Future<void> _run({required bool manual}) async {
    await _startup;
    if (!manual && !autoUpdate()) return;
    final before = status.value;
    _set(const UpdateChecking());
    try {
      final answer = await _feed.latest();
      if (answer.retryAt case final at?) {
        final local = at.toLocal();
        final time = '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
        _set(manual ? UpdateFailed('GitHub’s rate limit was reached: Kumo can check again after $time.') : before);
        return;
      }
      final release = answer.release;
      final ready = _ready == null ? null : UpdateVersion.parse(_ready!);
      if (release == null || release.version <= (ready ?? _current)) {
        _set(_ready == null ? const UpdateUpToDate() : UpdateReady(_ready!));
        return;
      }
      await _download(release);
    } on _UpdateError catch (e) {
      _set(UpdateFailed(e.message));
    } on Object catch (e) {
      _set(UpdateFailed('Couldn’t check for updates: ${e is HttpException ? e.message : e}'));
    }
  }

  /// [name] in [dir]: `\` on Windows, where this runs; the host's separator
  /// in tests on other OSes.
  static String _join(String dir, String name) => '$dir${Platform.pathSeparator}$name';

  /// This Kumo's own download folder for [version]: every workspace window
  /// is a Kumo process of its own, and none trusts another's files.
  String _folderFor(String version) {
    final random = Random.secure();
    final tag = List.generate(4, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    return _join(config.updatesDir, '$version.${_launcher.pid}.$tag');
  }

  Future<void> _download(FeedRelease release) async {
    final version = '${release.version}';
    _set(UpdateDownloading(version));
    final dir = Directory(_folderFor(version));
    try {
      await dir.create(recursive: true);
      // Held while this Kumo runs: another one starting leaves the folder be.
      _locks[dir.path] = _lockFolder(dir.path) ?? (throw _UpdateError('Couldn’t download Kumo $version: its folder is in use.'));
      final part = File(_join(dir.path, 'Kumo.zip.part'));
      try {
        await _net.download(release.zip, part);
      } on Object catch (e) {
        throw _UpdateError('Couldn’t download Kumo $version: ${e is HttpException ? e.message : e}');
      }
      final bytes = await part.readAsBytes();
      await part.delete();
      final sig = await _net.get(release.sig, headers: {'User-Agent': _userAgent});
      if (sig.status != 200) throw _UpdateError('Kumo $version has no signature, so it wasn’t installed.');
      String? sha;
      if (release.sha256 case final url?) {
        final reply = await _net.get(url, headers: {'User-Agent': _userAgent});
        if (reply.status != 200) throw _UpdateError('Couldn’t download Kumo $version’s checksum.');
        sha = reply.text;
      }
      final key = config.publicKey!;
      final sigText = sig.text;
      // Off the UI thread: hashing tens of MB in Dart takes a moment.
      final problem = await _problemOffThread(bytes, sigText, key, sha);
      if (problem != null) throw _UpdateError('Kumo $version wasn’t installed: $problem.');

      // Extract the very bytes just verified, never the download read again.
      final zip = File(_join(dir.path, 'Kumo.zip'));
      await zip.writeAsBytes(bytes, flush: true);
      await (_extract ?? _tarExtract)(zip.path, dir.path);
      final kumo = _join(dir.path, 'Kumo');
      final exe = _join(kumo, 'Kumo.exe');
      if (!File(exe).existsSync() || !File(_join(kumo, 'install.ps1')).existsSync()) {
        throw _UpdateError('Kumo $version’s download has no Kumo.exe or install.ps1.');
      }
      // The zip is signed, but not its name: the Kumo inside must be the
      // version it was published as, never this one or an older one.
      final inside = UpdateVersion.tryParse((await _exeVersion(exe))?.split('+').first ?? '');
      if (inside != release.version || inside! <= _current) {
        throw _UpdateError('Kumo $version’s download holds another version (${inside ?? 'unknown'}), so it wasn’t installed.');
      }

      final previous = _readyDir;
      _ready = version;
      _readyDir = kumo;
      _set(UpdateReady(version));
      if (!_disposed) notifyListeners();
      if (previous != null) _discard(Directory(previous).parent);
    } on Object {
      _discard(dir);
      rethrow;
    }
  }

  /// Each download folder's release, held while this Kumo runs.
  final _locks = <String, void Function()>{};

  /// Lets go of [dir], one of this Kumo's, and deletes it.
  void _discard(Directory dir) {
    try {
      _locks.remove(dir.path)?.call();
    } on FileSystemException {
      // Closed already.
    }
    _deleteQuietly(dir);
  }

  Future<void> _tarExtract(String zip, String into) async {
    final r = await Process.run(config.tar, ['-xf', zip, '-C', into]);
    if (r.exitCode != 0) throw _UpdateError('Couldn’t extract the update: ${'${r.stderr}'.trim()}');
  }

  /// [updateProblem] in another isolate; static, so the closure carries
  /// only its arguments there.
  static Future<String?> _problemOffThread(Uint8List zip, String signature, Uint8List key, String? sha256) =>
      Isolate.run(() => updateProblem(zip, signature: signature, publicKey: key, sha256: sha256));

  static Future<String?> _readExeVersion(String exe) async => productVersionIn(await File(exe).readAsBytes());

  static void _deleteQuietly(Directory dir) {
    try {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } on FileSystemException {
      // A file still open; the next start tries again.
    }
  }

  /// What `install.ps1` reports a failed update with (packaging/install.ps1.in).
  static const _failedLine = 'Kumo wasn\'t updated: ';

  /// Deletes the downloads no running Kumo holds (their update is
  /// installed, or failed) and says once if the last install failed.
  Future<void> _cleanUp() async {
    try {
      final root = Directory(config.updatesDir);
      if (!root.existsSync()) return;
      for (final entry in root.listSync()) {
        if (entry is! Directory) continue;
        if (File(_join(entry.path, '.lock')).existsSync()) {
          // Another Kumo's, still running: its update may be about to install.
          final release = _lockFolder(entry.path);
          if (release == null) continue;
          release();
        }
        _deleteQuietly(entry);
      }
      final log = File(_join(root.path, 'update.log'));
      if (!log.existsSync()) return;
      // Windows PowerShell writes it in the ANSI code page; the message
      // matters, not every accent.
      final lines = utf8.decode(await log.readAsBytes(), allowMalformed: true).split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty);
      if (lines.isEmpty) return;
      final last = lines.last.trim();
      final at = last.indexOf(_failedLine);
      if (at < 0) return;
      final reported = File(_join(root.path, 'update.log.reported'));
      if (reported.existsSync() && reported.readAsStringSync() == last) return;
      reported.writeAsStringSync(last);
      _set(UpdateFailed('The last update didn’t install: ${last.substring(at + _failedLine.length)}'));
    } on FileSystemException {
      // Nothing to clean or report.
    }
  }

  /// `install.ps1` from the ready version's folder, for this Kumo.
  List<String> _installerArgs(String kumo, {bool relaunch = true}) => [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-WindowStyle',
        'Hidden',
        '-File',
        _join(kumo, 'install.ps1'),
        '-From',
        kumo,
        '-WaitPid',
        '${_launcher.pid}',
        if (!relaunch) '-NoRelaunch',
      ];

  @override
  Future<void> installAndRelaunch() async {
    if (_readyDir != null) await _restart();
  }

  @override
  Future<void> relaunch() => _restart();

  /// Stops kumod, then quits into the installer when an update is ready,
  /// else just reopens Kumo.
  Future<void> _restart() async {
    await stopDaemon?.call();
    if (_readyDir != null) {
      // Gone, Kumo stays open to say so; the next check downloads it again.
      final kumo = _installable();
      if (kumo == null) return;
      try {
        await _launcher.start(config.powershell, _installerArgs(kumo));
        _launcher.exit(0);
        return;
      } on Object catch (e) {
        _set(UpdateFailed('Couldn’t start the update: $e'));
      }
    }
    await _relaunchApp();
  }

  /// The ready version's folder while its `install.ps1` is still there;
  /// gone, the update is forgotten (and downloaded again by the next check).
  String? _installable() {
    final kumo = _readyDir;
    if (kumo == null) return null;
    if (File(_join(kumo, 'install.ps1')).existsSync()) return kumo;
    final version = _ready;
    _ready = null;
    _readyDir = null;
    _discard(Directory(kumo).parent);
    _set(UpdateFailed('Kumo $version’s download is gone, so it wasn’t installed. Kumo will download it again.'));
    if (!_disposed) notifyListeners();
    return null;
  }

  /// Kumo is quitting: an update ready installs now, as Sparkle does on
  /// macOS. kumod keeps running (with its terminals) from the old files;
  /// the next Kumo restarts it on the new ones once it's idle.
  @visibleForTesting
  Future<AppExitResponse> installOnQuit() async {
    if (_installable() case final kumo?) {
      try {
        await _launcher.start(config.powershell, _installerArgs(kumo, relaunch: false));
      } on Object catch (e) {
        debugPrint('kumo: couldn’t start the update on quit: $e');
      }
    }
    return AppExitResponse.exit;
  }

  @override
  void dispose() {
    _disposed = true;
    _next?.cancel();
    _lifecycle?.dispose();
    super.dispose();
  }
}
