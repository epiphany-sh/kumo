import 'package:flutter/foundation.dart';

import 'pipelines_source.dart';

/// A host of the workspace's repositories (`github.com`), for its token.
@immutable
class CiHostInfo {
  const CiHostInfo({
    required this.host,
    required this.provider,
    this.hasToken = false,
    this.usesGh = false,
    this.ghAccount = '',
    this.ghAvailable = false,
    this.repos = const [],
  });
  final String host;
  final CiProvider provider;

  /// A token is saved in the Keychain.
  final bool hasToken;

  /// No saved token, but the GitHub CLI is signed in to the host.
  final bool usesGh;

  /// Who gh is signed in as on the host (empty when it isn't).
  final String ghAccount;

  /// gh is installed and can sign in to this host (GitHub hosts).
  final bool ghAvailable;

  /// `owner/name` of the workspace's repositories on it.
  final List<String> repos;
}

/// What a token check answered: who it signs in as, or what's wrong.
@immutable
class CiHostTest {
  const CiHostTest({this.message = '', this.problem});
  final String message;
  final CiProblem? problem;
}

/// Settings › Repositories: the hosts' tokens, kept by the daemon in the
/// Keychain. [MockCiHostsSource] backs the design and tests.
abstract class CiHostsSource {
  Future<List<CiHostInfo>> list();

  /// Saves [token] for [host]; an empty one removes it.
  Future<CiHostInfo> saveToken(String host, String token);

  /// Checks [token], or the saved one when empty.
  Future<CiHostTest> test(String host, {String token = ''});

  /// Opens a terminal running `gh auth login` for [host]; returns its id
  /// to show. The daemon notices when it's done.
  Future<String> signInWithGh(String host);
}

/// The design's hosts: GitHub signed in, GitLab without a token.
class MockCiHostsSource implements CiHostsSource {
  MockCiHostsSource({List<CiHostInfo>? hosts})
      : _hosts = hosts ??
            [
              const CiHostInfo(host: 'github.com', provider: CiProvider.githubActions, hasToken: true, ghAvailable: true, repos: ['pricing/price-admin']),
              const CiHostInfo(host: 'gitlab.fravega.com', provider: CiProvider.gitlabCi, repos: ['pricing/price-reader-v2']),
            ];

  List<CiHostInfo> _hosts;
  final saved = <(String, String)>[];
  final signIns = <String>[];

  @override
  Future<List<CiHostInfo>> list() async => _hosts;

  @override
  Future<CiHostInfo> saveToken(String host, String token) async {
    saved.add((host, token));
    _hosts = [
      for (final h in _hosts)
        if (h.host == host)
          CiHostInfo(host: h.host, provider: h.provider, hasToken: token.isNotEmpty, ghAvailable: h.ghAvailable, repos: h.repos)
        else
          h,
    ];
    return _hosts.firstWhere((h) => h.host == host);
  }

  @override
  Future<CiHostTest> test(String host, {String token = ''}) async => token == 'bad'
      ? const CiHostTest(problem: CiProblem(CiProblemKind.unauthorized, detail: 'HTTP 401 · Bad credentials'))
      : const CiHostTest(message: 'Signed in as ana');

  @override
  Future<String> signInWithGh(String host) async {
    signIns.add(host);
    return 'gh-login';
  }
}
