import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:grpc/grpc.dart';

import '../app/preferences.dart';
import '../data/profiles_source.dart';
import 'generated/kumo/v1/kumo.pbgrpc.dart' as pb;
import 'kumo_engine.dart';

/// Workspaces as `kumod` keeps them (`Profiles`, streamed by `Watch`). The
/// stream carries this window's workspace, so the daemon knows it's in use
/// and won't delete it. A daemon without profiles shows one workspace.
class EngineProfiles extends ProfilesSource {
  EngineProfiles(this._engine, this._prefs, {String? initial}) : _current = initial {
    _watch();
  }

  final KumoEngine _engine;
  final Preferences _prefs;
  bool _disposed = false;
  bool _supported = true;
  List<AppProfile> _profiles = const [];
  String? _current;
  StreamSubscription<pb.ProfileList>? _sub;
  Completer<void>? _restart;

  /// The stream ended to start again with another workspace: no pause.
  bool _again = false;

  AppProfile get _fallback => AppProfile(
        id: 'default',
        name: _prefs.get<String>('profile.name', ''),
        color: Color(_prefs.get<int>('profile.color', 0xFF8C9BFF)),
        worktreesDir: '~/wt/{repo}/{key}',
        isDefault: true,
      );

  @override
  bool get canManage => _supported && _profiles.isNotEmpty;

  @override
  bool get loading => _supported && _profiles.isEmpty;

  /// Before the list arrives: this window's own workspace (a new window's),
  /// else the default one.
  @override
  List<AppProfile> get profiles {
    if (_profiles.isNotEmpty) return _profiles;
    final id = _current;
    if (id != null && id != 'default' && _supported) return [AppProfile(id: id, name: '', color: profileColors.first.$2)];
    return [_fallback];
  }

  /// Until the list arrives, the default one.
  @override
  String get currentId {
    final id = _current;
    final all = profiles;
    // Before the list arrives, the window's own one (a new window's).
    if (id != null && (_profiles.isEmpty || all.any((p) => p.id == id))) return id;
    return all.where((p) => p.isDefault).firstOrNull?.id ?? all.first.id;
  }

  Future<pb.ProfilesClient> get _client async => (await _engine.connection()).profiles;

  CallOptions get _asCurrent => CallOptions(metadata: {'kumo-profile': currentId});

  Future<void> _watch() async {
    while (!_disposed) {
      final ended = Completer<void>();
      _restart = ended;
      try {
        final stream = (await _client).watch(pb.WatchProfilesRequest(), options: _asCurrent);
        _sub = stream.listen(
          (list) {
            if (_disposed) return;
            _supported = true;
            _profiles = [for (final p in list.profiles) profileFrom(p)];
            notifyListeners();
          },
          onError: (Object e) {
            if (e is GrpcError && e.code == StatusCode.unimplemented) _unsupported();
            if (!ended.isCompleted) ended.complete();
          },
          onDone: () {
            if (!ended.isCompleted) ended.complete();
          },
          cancelOnError: true,
        );
        await ended.future;
      } on GrpcError catch (e) {
        if (e.code == StatusCode.unimplemented) _unsupported();
      } on Object {
        // A restarting daemon ends every stream; the next one reconnects.
      }
      await _sub?.cancel();
      _sub = null;
      if (_disposed) return;
      // An older kumod: look again now and then (it may be updated in place).
      if (!_again) await Future<void>.delayed(Duration(seconds: _supported ? 2 : 30));
      _again = false;
    }
  }

  void _unsupported() {
    _supported = false;
    _profiles = const [];
    notifyListeners();
  }

  Future<T> _call<T>(Future<T> Function(pb.ProfilesClient c) call) async {
    try {
      return await call(await _client);
    } on GrpcError catch (e) {
      if (e.code == StatusCode.unimplemented) {
        _unsupported();
        throw 'This kumod keeps one workspace: update it to keep workspaces apart.';
      }
      throw e.message ?? e.codeName;
    }
  }

  @override
  Future<void> select(String id) async {
    if (id == currentId || !profiles.any((p) => p.id == id)) return;
    _current = id;
    notifyListeners();
    // The stream now says this window is on [id].
    _again = true;
    await _sub?.cancel();
    _sub = null;
    final r = _restart;
    if (r != null && !r.isCompleted) r.complete();
  }

  @override
  Future<AppProfile> create({required String name, required Color color, String? copyAgentsFrom}) async {
    final p = await _call((c) => c.create(pb.CreateProfileRequest(name: name.trim(), color: colorHex(color), copyAgentsFrom: copyAgentsFrom ?? '')));
    final made = profileFrom(p);
    if (!_profiles.any((x) => x.id == made.id)) {
      _profiles = [..._profiles, made];
      notifyListeners();
    }
    return made;
  }

  @override
  Future<void> update(String id, ProfileChanges ch) async {
    if (!_supported) {
      // An older daemon: the one workspace's name and color live here.
      if (ch.name case final n?) _prefs.set('profile.name', n.trim());
      if (ch.color case final col?) _prefs.set('profile.color', col.toARGB32());
      notifyListeners();
      return;
    }
    final p = await _call((c) => c.update(pb.UpdateProfileRequest(
          id: id,
          name: ch.name?.trim(),
          color: ch.color == null ? null : colorHex(ch.color!),
          worktreesDir: ch.worktreesDir,
          gitName: ch.gitName,
          gitEmail: ch.gitEmail,
          sshKey: ch.sshKey,
          signCommits: ch.signCommits,
          ghAccounts: ch.ghAccounts == null ? null : pb.GhAccounts(accounts: [for (final (host, login) in ch.ghAccounts!) pb.GhAccount(host: host, login: login)]),
        )));
    final updated = profileFrom(p);
    _profiles = [for (final x in _profiles) x.id == id ? updated : x];
    notifyListeners();
  }

  @override
  Future<void> delete(String id) async {
    await _call((c) => c.delete(pb.DeleteProfileRequest(id: id)));
    _profiles = [for (final x in _profiles) if (x.id != id) x];
    notifyListeners();
  }

  @override
  Future<List<SshKeyInfo>> sshKeys() async {
    if (!canManage) return const [];
    final list = await _call((c) => c.listSshKeys(pb.ListSshKeysRequest()));
    return [
      for (final k in list.keys) SshKeyInfo(name: k.name, path: k.path, fingerprint: k.fingerprint, kind: k.kind, agentOnly: k.agentOnly),
    ];
  }

  @override
  Future<List<(String, String)>> ghAccounts() async {
    if (!canManage) return const [];
    final list = await _call((c) => c.listGhAccounts(pb.ListGhAccountsRequest()));
    return [for (final a in list.accounts) (a.host, a.login)];
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    final r = _restart;
    if (r != null && !r.isCompleted) r.complete();
    super.dispose();
  }
}

AppProfile profileFrom(pb.Profile p) => AppProfile(
      id: p.id,
      name: p.name,
      color: colorFromHex(p.color) ?? profileColors.first.$2,
      worktreesDir: p.worktreesDir,
      isDefault: p.isDefault,
      agentsRunning: p.agentsRunning,
      agentsWaiting: p.agentsWaiting,
      terminalsOpen: p.terminalsOpen,
      namespaces: p.namespaces,
      repos: p.repos,
      gitName: p.gitName,
      gitEmail: p.gitEmail,
      sshKey: p.sshKey,
      signCommits: p.signCommits,
      ghAccounts: [for (final a in p.ghAccounts) (a.host, a.login)],
    );

/// "#8C9BFF" ↔ Color.
String colorHex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';

Color? colorFromHex(String hex) {
  final h = hex.trim().replaceFirst('#', '');
  if (h.length != 6) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(0xFF000000 | v);
}
