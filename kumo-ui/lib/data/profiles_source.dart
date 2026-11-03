import 'package:flutter/widgets.dart';

import '../app/preferences.dart';

/// A workspace: one company, client or the user's own projects, with its
/// own Git hosts and tokens, task sources, docs, agents' sign-ins and
/// namespaces. The daemon keeps each apart; it calls them profiles.
@immutable
class AppProfile {
  const AppProfile({
    required this.id,
    required this.name,
    required this.color,
    this.worktreesDir = '',
    this.isDefault = false,
    this.agentsRunning = 0,
    this.agentsWaiting = 0,
    this.namespaces = 0,
    this.repos = 0,
    this.terminalsOpen = 0,
    this.gitName = '',
    this.gitEmail = '',
    this.sshKey = '',
    this.signCommits = false,
    this.ghAccounts = const [],
  });

  final String id;
  final String name;
  final Color color;

  /// Where its worktrees go, e.g. `~/wt/personal/{repo}/{key}`.
  final String worktreesDir;

  /// The one that holds what Kumo had before workspaces existed.
  final bool isDefault;
  final int agentsRunning;

  /// Agents whose turn ended: they need the user.
  final int agentsWaiting;
  final int namespaces;
  final int repos;
  final int terminalsOpen;

  /// Who commits here; empty: the user's git config.
  final String gitName;
  final String gitEmail;

  /// The SSH key git uses here (`~/.ssh/id_work`); empty: none.
  final String sshKey;

  /// Sign commits with [sshKey].
  final bool signCommits;

  /// The `gh` account it uses per host: (host, login).
  final List<(String, String)> ghAccounts;

  /// The default workspace before the user names it.
  String get displayName => name.trim().isEmpty ? 'Workspace' : name.trim();

  String get initial => displayName.characters.first.toUpperCase();

  /// "3 agents running", "1 agent needs you", "Nothing running".
  String get activity {
    if (agentsWaiting > 0) return agentsWaiting == 1 ? '1 agent needs you' : '$agentsWaiting agents need you';
    if (agentsRunning > 0) return agentsRunning == 1 ? '1 agent running' : '$agentsRunning agents running';
    return 'Nothing running';
  }

  /// "2 namespaces · 3 repos".
  String get summary => namespaces == 0
      ? 'No namespaces yet'
      : '$namespaces ${namespaces == 1 ? 'namespace' : 'namespaces'} · $repos ${repos == 1 ? 'repo' : 'repos'}';

  AppProfile copyWith({
    String? name,
    Color? color,
    String? worktreesDir,
    String? gitName,
    String? gitEmail,
    String? sshKey,
    bool? signCommits,
    List<(String, String)>? ghAccounts,
  }) =>
      AppProfile(
        id: id,
        name: name ?? this.name,
        color: color ?? this.color,
        worktreesDir: worktreesDir ?? this.worktreesDir,
        isDefault: isDefault,
        agentsRunning: agentsRunning,
        agentsWaiting: agentsWaiting,
        namespaces: namespaces,
        repos: repos,
        terminalsOpen: terminalsOpen,
        gitName: gitName ?? this.gitName,
        gitEmail: gitEmail ?? this.gitEmail,
        sshKey: sshKey ?? this.sshKey,
        signCommits: signCommits ?? this.signCommits,
        ghAccounts: ghAccounts ?? this.ghAccounts,
      );
}

/// The colors a workspace can take (its switcher tile).
const profileColors = <(String, Color)>[
  ('Indigo', Color(0xFF8C9BFF)),
  ('Green', Color(0xFF4CC38A)),
  ('Orange', Color(0xFFF2A65A)),
  ('Pink', Color(0xFFE879A6)),
  ('Sky', Color(0xFF5BC0EB)),
  ('Lavender', Color(0xFFB39DDB)),
];

/// `~/wt/<slug>/{repo}/{key}`.
String worktreesDirFor(String name) {
  final slug = name.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-+|-+$'), '');
  return '~/wt/${slug.isEmpty ? '{workspace}' : slug}/{repo}/{key}';
}

/// An SSH key in ~/.ssh a workspace can use (never what it holds).
@immutable
class SshKeyInfo {
  const SshKeyInfo({required this.name, required this.path, this.fingerprint = '', this.kind = '', this.agentOnly = false});
  final String name;

  /// What [AppProfile.sshKey] takes: `~/.ssh/id_ed25519`.
  final String path;
  final String fingerprint;
  final String kind;

  /// Only the .pub is on disk (an agent such as 1Password holds the key).
  final bool agentOnly;
}

/// What [ProfilesSource.update] changes; null fields stay as they are.
@immutable
class ProfileChanges {
  const ProfileChanges({this.name, this.color, this.worktreesDir, this.gitName, this.gitEmail, this.sshKey, this.signCommits, this.ghAccounts});
  final String? name;
  final Color? color;
  final String? worktreesDir;

  /// Empty: back to the user's git config.
  final String? gitName;
  final String? gitEmail;

  /// Empty: no key.
  final String? sshKey;
  final bool? signCommits;

  /// Replaces them all.
  final List<(String, String)>? ghAccounts;
}

/// The user's workspaces and the one this window shows.
abstract class ProfilesSource extends ChangeNotifier {
  /// More than one workspace is possible (false: this daemon has only one,
  /// or the list hasn't arrived yet: see [loading]).
  bool get canManage;

  /// The daemon's list is on its way.
  bool get loading => false;

  List<AppProfile> get profiles;
  String get currentId;

  AppProfile get current => profiles.where((p) => p.id == currentId).firstOrNull ?? profiles.first;

  /// This window now shows [id]; nothing of the one it leaves stops.
  Future<void> select(String id);

  /// [copyAgentsFrom]: copy that workspace's agent commands (never their
  /// sign-ins, tokens or history). Throws a readable message.
  Future<AppProfile> create({required String name, required Color color, String? copyAgentsFrom});

  Future<void> update(String id, ProfileChanges changes);

  /// Its tokens leave the Keychain; repos and worktrees stay on disk.
  /// Throws for the default one, the current one or the last one.
  Future<void> delete(String id);

  /// Keys in ~/.ssh a workspace can pick.
  Future<List<SshKeyInfo>> sshKeys() async => const [];

  /// Every account `gh` is signed in to: (host, login).
  Future<List<(String, String)>> ghAccounts() async => const [];
}

/// The design canvas: Fravega (where everything so far lives), Personal
/// and Acme Consulting.
class MockProfilesSource extends ProfilesSource {
  MockProfilesSource({List<AppProfile>? profiles, String? current}) : _profiles = profiles ?? designProfiles {
    _current = current ?? _profiles.first.id;
  }

  static const designProfiles = [
    AppProfile(id: 'default', name: 'Fravega', color: Color(0xFF8C9BFF), worktreesDir: '~/wt/{repo}/{key}', isDefault: true, agentsRunning: 3, agentsWaiting: 1, namespaces: 2, repos: 3),
    AppProfile(id: 'personal', name: 'Personal', color: Color(0xFF4CC38A), worktreesDir: '~/wt/personal/{repo}/{key}', agentsRunning: 1, agentsWaiting: 1, namespaces: 2, repos: 3),
    AppProfile(id: 'acme', name: 'Acme Consulting', color: Color(0xFFF2A65A), worktreesDir: '~/wt/acme/{repo}/{key}', namespaces: 1, repos: 1),
  ];

  List<AppProfile> _profiles;
  late String _current;

  @override
  bool get canManage => true;
  @override
  List<AppProfile> get profiles => List.unmodifiable(_profiles);
  @override
  String get currentId => _current;

  @override
  Future<void> select(String id) async {
    if (!_profiles.any((p) => p.id == id) || id == _current) return;
    _current = id;
    notifyListeners();
  }

  @override
  Future<AppProfile> create({required String name, required Color color, String? copyAgentsFrom}) async {
    final n = name.trim();
    if (n.isEmpty) throw 'Name the workspace first.';
    if (_profiles.any((p) => p.name.toLowerCase() == n.toLowerCase())) throw 'There’s already a workspace called $n.';
    var id = n.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    while (_profiles.any((p) => p.id == id)) {
      id = '$id-2';
    }
    final p = AppProfile(id: id, name: n, color: color, worktreesDir: worktreesDirFor(n));
    _profiles = [..._profiles, p];
    notifyListeners();
    return p;
  }

  @override
  Future<void> update(String id, ProfileChanges changes) async {
    final n = changes.name?.trim();
    if (n != null && n.isEmpty) throw 'A workspace needs a name.';
    if (n != null && _profiles.any((p) => p.id != id && p.name.toLowerCase() == n.toLowerCase())) throw 'There’s already a workspace called $n.';
    _profiles = [
      for (final p in _profiles)
        p.id == id
            ? p.copyWith(
                name: n,
                color: changes.color,
                worktreesDir: changes.worktreesDir,
                gitName: changes.gitName,
                gitEmail: changes.gitEmail,
                sshKey: changes.sshKey,
                signCommits: changes.signCommits,
                ghAccounts: changes.ghAccounts,
              )
            : p,
    ];
    notifyListeners();
  }

  @override
  Future<List<SshKeyInfo>> sshKeys() async => const [
        SshKeyInfo(name: 'id_ed25519', path: '~/.ssh/id_ed25519', fingerprint: 'SHA256:4b2M…Qe8', kind: 'ed25519'),
        SshKeyInfo(name: 'id_personal', path: '~/.ssh/id_personal', fingerprint: 'SHA256:Zp1x…7Ka', kind: 'ed25519'),
      ];

  @override
  Future<List<(String, String)>> ghAccounts() async => const [('github.com', 'mauri-fravega'), ('github.com', 'mauri')];

  @override
  Future<void> delete(String id) async {
    if (_profiles.any((p) => p.id == id && p.isDefault)) throw 'The first workspace holds what Kumo had before workspaces: it can’t be deleted.';
    if (id == _current) throw 'This window is on it: switch to another workspace first.';
    if (_profiles.length <= 1) throw 'Kumo needs at least one workspace.';
    _profiles = [for (final p in _profiles) if (p.id != id) p];
    notifyListeners();
  }
}

/// A daemon without workspaces (older kumod): everything is one, which the
/// user can still name. Creating another says why it can't.
class SingleProfileSource extends ProfilesSource {
  SingleProfileSource(this._prefs);
  final Preferences _prefs;

  AppProfile get _only => AppProfile(
        id: 'default',
        name: _prefs.get<String>('profile.name', 'Workspace'),
        color: Color(_prefs.get<int>('profile.color', 0xFF8C9BFF)),
        worktreesDir: '~/wt/{repo}/{key}',
        isDefault: true,
      );

  @override
  bool get canManage => false;
  @override
  List<AppProfile> get profiles => [_only];
  @override
  String get currentId => 'default';
  @override
  Future<void> select(String id) async {}

  @override
  Future<AppProfile> create({required String name, required Color color, String? copyAgentsFrom}) async =>
      throw 'This kumod keeps one workspace: update it to keep workspaces apart.';

  @override
  Future<void> update(String id, ProfileChanges changes) async {
    final n = changes.name?.trim();
    if (n != null && n.isEmpty) throw 'A workspace needs a name.';
    if (n != null) _prefs.set('profile.name', n);
    if (changes.color != null) _prefs.set('profile.color', changes.color!.toARGB32());
    notifyListeners();
  }

  @override
  Future<void> delete(String id) async => throw 'Kumo needs at least one workspace.';
}
