import 'dart:async';
import 'dart:convert';
import 'dart:io' as io show exit, pid;
import 'dart:io';
import 'dart:isolate';
import 'dart:math' show Random, max, min;
import 'dart:typed_data';
import 'dart:ui' show AppExitResponse;

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show AppLifecycleListener;

import 'channel.dart';
import 'os/host_os.dart';
import 'updates.dart';

/// A release version, X.Y.Z or X.Y.Z-prerelease (`0.10.0-beta.1`), ordered
/// as semver orders them: a prerelease before its release, its identifiers
/// one by one (numbers as numbers, and before words).
@immutable
class UpdateVersion implements Comparable<UpdateVersion> {
  const UpdateVersion(this.major, this.minor, this.patch, [this.pre = const []]);

  final int major;
  final int minor;
  final int patch;

  /// The prerelease identifiers (`beta`, `1`); empty for a release.
  final List<String> pre;

  bool get isPrerelease => pre.isNotEmpty;

  static final _pattern = RegExp(r'^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$');
  static final _numeric = RegExp(r'^\d+$');

  /// `X.Y.Z`, `X.Y.Z-pre` or either with a `v`; null for anything else
  /// (`1.2`, `1.2.3-`, build metadata).
  static UpdateVersion? tryParse(String text) {
    final m = _pattern.firstMatch(text.trim());
    if (m == null) return null;
    return UpdateVersion(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!), m[4]?.split('.') ?? const []);
  }

  static UpdateVersion parse(String text) => tryParse(text) ?? (throw FormatException('Not a version: $text'));

  @override
  int compareTo(UpdateVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    if (pre.isEmpty || other.pre.isEmpty) return (pre.isEmpty ? 1 : 0) - (other.pre.isEmpty ? 1 : 0);
    for (var i = 0; i < pre.length && i < other.pre.length; i++) {
      final order = _compareIdentifiers(pre[i], other.pre[i]);
      if (order != 0) return order;
    }
    return pre.length.compareTo(other.pre.length);
  }

  static int _compareIdentifiers(String a, String b) {
    final an = _numeric.hasMatch(a), bn = _numeric.hasMatch(b);
    if (an && bn) return BigInt.parse(a).compareTo(BigInt.parse(b));
    if (an != bn) return an ? -1 : 1;
    return a.compareTo(b);
  }

  bool operator >(UpdateVersion other) => compareTo(other) > 0;
  bool operator <=(UpdateVersion other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) => other is UpdateVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, Object.hashAll(pre));

  @override
  String toString() => pre.isEmpty ? '$major.$minor.$patch' : '$major.$minor.$patch-${pre.join('.')}';
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
    String? updatesDir,
    this.feed = '',
    this.prereleases = false,
  }) : _updatesDir = updatesDir;

  /// This build's, from `packaging/windows-zip.sh` (`--dart-define`).
  factory UpdateConfig.fromEnvironment(Map<String, String> env) => UpdateConfig(
        version: const String.fromEnvironment('KUMO_VERSION'),
        repo: const String.fromEnvironment('KUMO_RELEASE_REPO'),
        key: const String.fromEnvironment('KUMO_UPDATE_KEY'),
        feed: const String.fromEnvironment('KUMO_UPDATE_FEED'),
        prereleases: const bool.fromEnvironment('KUMO_UPDATE_PRERELEASES'),
        channel: kumoChannel,
        debug: kDebugMode,
        exe: Platform.resolvedExecutable,
        localAppData: env['LOCALAPPDATA'] ?? '',
      );

  /// X.Y.Z.
  final String version;

  /// owner/name on GitHub.
  final String repo;

  /// Base64 of the 32-byte ed25519 public key the `.sig` is checked with.
  final String key;

  /// `KUMO_CHANNEL`: a beta or sandbox build never takes a release.
  final String channel;

  /// `KUMO_UPDATE_FEED`: a URL answering as GitHub's releases list does,
  /// read instead of [repo]'s (to try an update against a local server);
  /// empty for GitHub. Set when building only: nothing at run time can
  /// point a build elsewhere, and what it downloads is still checked
  /// against [key].
  final String feed;

  /// `KUMO_UPDATE_PRERELEASES`: whether GitHub prereleases and `-beta`
  /// versions count as updates. Off, a beta installed by hand still
  /// updates to the next release.
  final bool prereleases;

  /// Where the releases are listed.
  Uri get feedUrl => feed.isNotEmpty ? Uri.parse(feed) : Uri.parse('https://api.github.com/repos/$repo/releases?per_page=20');
  final bool debug;

  /// The running Kumo.exe.
  final String exe;
  final String localAppData;
  final String? _updatesDir;

  /// Where `install.ps1` puts Kumo (its default `-Dest`).
  String get installDir => '$localAppData\\Programs\\Kumo';

  /// Downloads, one folder per version, the installer's `setup.log` and
  /// the `update.log` it (or `install.ps1`) reports a failed update in.
  String get updatesDir => _updatesDir ?? '$localAppData\\Kumo\\updates';

  /// The public key's bytes, or null when [key] isn't one.
  Uint8List? get publicKey {
    try {
      final bytes = base64.decode(key.trim());
      return bytes.length == 32 ? bytes : null;
    } on FormatException {
      return null;
    }
  }

  /// A release build with all it needs, running from where the installer
  /// (or `install.ps1`) put it: never a build folder, which an update would
  /// replace.
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

/// A Windows build on GitHub: its installer, signature and checksum.
class FeedRelease {
  const FeedRelease(this.version, this.installer, this.sig, this.sha256);
  final UpdateVersion version;

  /// `Kumo-X.Y.Z-windows-x64-setup.exe`.
  final Uri installer;
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

/// GitHub's releases of [repo] (or another list at [url]): the newest
/// published one with a signed Windows installer. Not "latest", which is
/// the newest with the macOS build (`docs/releasing.md`).
class UpdateFeed {
  UpdateFeed(this.http, {required this.repo, required this.userAgent, required this.now, Uri? url, this.prereleases = false}) : _url = url;

  final UpdateHttp http;
  final String repo;
  final String userAgent;
  final DateTime Function() now;

  /// Whether prereleases count ([UpdateConfig.prereleases]).
  final bool prereleases;
  final Uri? _url;

  String? _etag;
  FeedRelease? _last;
  DateTime? _retryAt;

  Uri get url => _url ?? Uri.parse('https://api.github.com/repos/$repo/releases?per_page=20');

  static final _setupName = RegExp(r'^Kumo-(\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?)-windows-x64-setup\.exe$');

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
        final release = newest(jsonDecode(reply.text), prereleases: prereleases);
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
  /// prerelease (unless [prereleases]), whose tag is its version and whose
  /// setup.exe has a `.sig`. Releases with only the zip (0.9.0 and older)
  /// are left to the updaters that install zips.
  static FeedRelease? newest(Object? releases, {bool prereleases = false}) {
    FeedRelease? best;
    if (releases is! List) return null;
    for (final r in releases) {
      if (r is! Map || r['draft'] == true || (r['prerelease'] == true && !prereleases)) continue;
      final tag = UpdateVersion.tryParse('${r['tag_name']}');
      final assets = <String, Uri>{};
      for (final a in r['assets'] is List ? r['assets'] as List : const []) {
        if (a is! Map || a['name'] is! String || a['browser_download_url'] is! String) continue;
        if (Uri.tryParse(a['browser_download_url'] as String) case final url?) assets[a['name'] as String] = url;
      }
      for (final MapEntry(key: name, value: installer) in assets.entries) {
        final version = UpdateVersion.tryParse(_setupName.firstMatch(name)?[1] ?? '');
        final sig = assets['$name.sig'];
        if (version == null || version != tag || sig == null) continue;
        if (version.isPrerelease && !prereleases) continue;
        if (best == null || version > best.version) best = FeedRelease(version, installer, sig, assets['$name.sha256']);
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
/// installer has the version it installs (`packaging/windows/kumo.iss`);
/// Kumo.exe has `flutter build --build-name` plus `+` and the build number
/// (`windows/runner/Runner.rc`).
///
/// Only the PE image is read, never data appended after it: a setup.exe's
/// payload holds other executables, with versions of their own.
String? productVersionIn(Uint8List bytes) {
  const key = 'ProductVersion\u0000';
  final needle = Uint8List(key.length * 2);
  for (var i = 0; i < key.length; i++) {
    needle[i * 2] = key.codeUnitAt(i) & 0xff;
    needle[i * 2 + 1] = key.codeUnitAt(i) >> 8;
  }
  final end = _peImageEnd(bytes) ?? bytes.length;
  // The resources come last in the image: look from its end.
  outer:
  for (var at = end - needle.length; at >= 0; at--) {
    for (var j = 0; j < needle.length; j++) {
      if (bytes[at + j] != needle[j]) continue outer;
    }
    var i = at + needle.length;
    int unit(int i) => i + 1 < end ? bytes[i] | bytes[i + 1] << 8 : -1;
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

/// Where a PE file's image ends (its last section's raw data), or null when
/// [bytes] isn't one.
int? _peImageEnd(Uint8List bytes) {
  if (bytes.length < 0x40 || bytes[0] != 0x4d || bytes[1] != 0x5a) return null;
  final view = ByteData.sublistView(bytes);
  final pe = view.getUint32(0x3c, Endian.little);
  if (pe + 24 > bytes.length || bytes[pe] != 0x50 || bytes[pe + 1] != 0x45 || bytes[pe + 2] != 0 || bytes[pe + 3] != 0) return null;
  final sections = view.getUint16(pe + 6, Endian.little);
  var at = pe + 24 + view.getUint16(pe + 20, Endian.little);
  var end = 0;
  for (var i = 0; i < sections; i++, at += 40) {
    if (at + 40 > bytes.length) return null;
    final size = view.getUint32(at + 16, Endian.little);
    if (size > 0) end = max(end, view.getUint32(at + 20, Endian.little) + size);
  }
  return end == 0 ? null : min(end, bytes.length);
}

/// Why [file] (an installer) must not run, or null when [signature] (base64
/// of a raw ed25519 signature) is [publicKey]'s over it and [sha256] (hex,
/// when given) is its hash.
Future<String?> updateProblem(Uint8List file, {required String signature, required Uint8List publicKey, String? sha256}) async {
  final List<int> sig;
  try {
    sig = base64.decode(signature.trim());
  } on FormatException {
    return 'its signature isn’t readable';
  }
  if (sig.length != 64) return 'its signature isn’t readable';
  if (sha256 != null) {
    final expected = sha256.trim().split(RegExp(r'\s+')).first.toLowerCase();
    final actual = (await Sha256().hash(file)).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    if (actual != expected) return 'it doesn’t match its checksum';
  }
  final ok = await Ed25519().verify(file, signature: Signature(sig, publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519)));
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
/// Settings › General › "Download updates automatically" is on; "Check for
/// Updates…" checks now), downloads a newer
/// `Kumo-X.Y.Z-windows-x64-setup.exe`, checks its ed25519 signature and
/// keeps it in `%LOCALAPPDATA%\Kumo\updates\<version>.<pid>.<tag>`. Then
/// it's [ready]: restarting runs that installer silently, which waits for
/// Kumo to exit, swaps the files (`packaging/windows/kumo.iss`) and opens
/// Kumo again; quitting runs it without the reopening.
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
  final ExeVersionReader _exeVersion;
  final Future<bool> Function() _relaunchApp;
  final UpdateFolderLock _lockFolder;
  /// Settings › General › "Download updates automatically", read before
  /// each background check; a manual [check] runs anyway.
  final bool Function() autoUpdate;
  final UpdateHttp? _http;

  late final UpdateHttp _net = _http ?? IoUpdateHttp(userAgent: _userAgent);
  late final UpdateFeed _feed = UpdateFeed(_net, repo: config.repo, userAgent: _userAgent, now: _now, url: config.feedUrl, prereleases: config.prereleases);
  String get _userAgent => 'Kumo/${config.version} (Windows)';

  late final UpdateVersion _current;
  Future<void>? _startup;
  Future<void>? _inFlight;
  Timer? _next;
  AppLifecycleListener? _lifecycle;
  var _disposed = false;

  String? _ready;

  /// The ready version's setup.exe.
  String? _readyInstaller;

  @override
  String? get ready => _ready;

  /// The ready version's setup.exe, in this Kumo's own download folder.
  @visibleForTesting
  String? get readyInstaller => _readyInstaller;

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
      final name = 'Kumo-$version-windows-x64-setup.exe';
      final part = File(_join(dir.path, '$name.part'));
      try {
        await _net.download(release.installer, part);
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

      // Keep the very bytes just verified, never the download read again.
      final setup = File(_join(dir.path, name));
      await setup.writeAsBytes(bytes, flush: true);
      // The installer is signed, but not its name: it must install the
      // version it was published as, never this one or an older one.
      final inside = UpdateVersion.tryParse((await _exeVersion(setup.path))?.split('+').first ?? '');
      if (inside != release.version || inside! <= _current) {
        throw _UpdateError('Kumo $version’s installer holds another version (${inside ?? 'unknown'}), so it wasn’t installed.');
      }

      final previous = _readyInstaller;
      _ready = version;
      _readyInstaller = setup.path;
      _set(UpdateReady(version));
      if (!_disposed) notifyListeners();
      if (previous != null) _discard(File(previous).parent);
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

  /// [updateProblem] in another isolate; static, so the closure carries
  /// only its arguments there.
  static Future<String?> _problemOffThread(Uint8List file, String signature, Uint8List key, String? sha256) =>
      Isolate.run(() => updateProblem(file, signature: signature, publicKey: key, sha256: sha256));

  /// Off the UI thread too: an installer is tens of MB.
  static Future<String?> _readExeVersion(String exe) => Isolate.run(() async => productVersionIn(await File(exe).readAsBytes()));

  static void _deleteQuietly(Directory dir) {
    try {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } on FileSystemException {
      // A file still open; the next start tries again.
    }
  }

  /// What the installer (`packaging/windows/kumo.iss`) and `install.ps1`
  /// report a failed update with.
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

  /// The installer, silent, once this Kumo has exited (`/WAITPID`), opening
  /// Kumo again unless quitting (`/RELAUNCH`); `packaging/windows/kumo.iss`.
  List<String> _installerArgs({bool relaunch = true}) => [
        '/VERYSILENT',
        '/SUPPRESSMSGBOXES',
        '/NORESTART',
        '/WAITPID=${_launcher.pid}',
        '/LOG=${_join(config.updatesDir, 'setup.log')}',
        if (relaunch) '/RELAUNCH',
      ];

  @override
  Future<void> installAndRelaunch() async {
    if (_readyInstaller != null) await _restart();
  }

  @override
  Future<void> relaunch() => _restart();

  /// Stops kumod, then quits into the installer when an update is ready,
  /// else just reopens Kumo.
  Future<void> _restart() async {
    await stopDaemon?.call();
    if (_readyInstaller != null) {
      // Gone, Kumo stays open to say so; the next check downloads it again.
      final setup = _installable();
      if (setup == null) return;
      try {
        await _launcher.start(setup, _installerArgs());
        _launcher.exit(0);
        return;
      } on Object catch (e) {
        _set(UpdateFailed('Couldn’t start the update: $e'));
      }
    }
    await _relaunchApp();
  }

  /// The ready version's installer while it's still there; gone, the update
  /// is forgotten (and downloaded again by the next check).
  String? _installable() {
    final setup = _readyInstaller;
    if (setup == null) return null;
    if (File(setup).existsSync()) return setup;
    final version = _ready;
    _ready = null;
    _readyInstaller = null;
    _discard(File(setup).parent);
    _set(UpdateFailed('Kumo $version’s download is gone, so it wasn’t installed. Kumo will download it again.'));
    if (!_disposed) notifyListeners();
    return null;
  }

  /// Kumo is quitting: an update ready installs now, as Sparkle does on
  /// macOS. kumod keeps running (with its terminals) from the old files;
  /// the next Kumo restarts it on the new ones once it's idle.
  @visibleForTesting
  Future<AppExitResponse> installOnQuit() async {
    if (_installable() case final setup?) {
      try {
        await _launcher.start(setup, _installerArgs(relaunch: false));
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
