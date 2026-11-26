import 'package:flutter_test/flutter_test.dart';
import 'package:kumo_ui/data/branch_links.dart';
import 'package:kumo_ui/data/pull_requests_source.dart';

void main() {
  group('remoteWebOf', () {
    test('reads the repository page from every usual remote form', () {
      const cases = {
        'git@github.com:platform/repo-a.git': 'https://github.com/platform/repo-a',
        'ssh://git@github.com/platform/repo-a.git': 'https://github.com/platform/repo-a',
        'https://github.com/platform/repo-a.git': 'https://github.com/platform/repo-a',
        'https://github.com/platform/repo-a': 'https://github.com/platform/repo-a',
        'https://github.com/platform/repo-a/': 'https://github.com/platform/repo-a',
        'ssh://git@gitlab.acme.io:2222/group/sub/infra.git': 'https://gitlab.acme.io/group/sub/infra',
        'https://user@bitbucket.org/identity/users.git': 'https://bitbucket.org/identity/users',
        '  git@github.com:platform/repo-a.git\n': 'https://github.com/platform/repo-a',
      };
      for (final MapEntry(key: remote, value: page) in cases.entries) {
        expect(remoteWebOf(remote)?.url, page, reason: remote);
      }
    });

    test('keeps the port and scheme of a web remote, not of an ssh one', () {
      expect(remoteWebOf('https://gitlab.corp.example:8443/team/repo.git')?.url, 'https://gitlab.corp.example:8443/team/repo');
      expect(remoteWebOf('http://gitlab.corp.example:8080/team/repo.git')?.url, 'http://gitlab.corp.example:8080/team/repo');
      expect(remoteWebOf('https://me:secret@gitlab.corp.example:8443/team/repo.git')?.url, 'https://gitlab.corp.example:8443/team/repo');
      expect(remoteWebOf('ssh://git@gitlab.corp.example:2222/team/repo.git')?.url, 'https://gitlab.corp.example/team/repo');
      expect(remoteWebOf('git://gitlab.corp.example:9418/team/repo.git')?.url, 'https://gitlab.corp.example/team/repo');
    });

    test('never keeps credentials from an https remote', () {
      expect(remoteWebOf('https://me:ghp_secret@github.com/platform/repo-a.git')?.url, 'https://github.com/platform/repo-a');
    });

    test('tells the host apart', () {
      expect(remoteWebOf('git@github.com:o/r.git')?.host, WebHost.github);
      expect(remoteWebOf('git@gitlab.com:o/r.git')?.host, WebHost.gitlab);
      expect(remoteWebOf('git@bitbucket.org:o/r.git')?.host, WebHost.bitbucket);
    });

    test('nothing for unknown hosts, local paths or no remote', () {
      expect(remoteWebOf(''), isNull);
      expect(remoteWebOf('git@git.acme.io:team/tool.git'), isNull);
      expect(remoteWebOf('/srv/git/repo.git'), isNull);
      expect(remoteWebOf(r'C:\repos\repo.git'), isNull);
      expect(remoteWebOf('file:///srv/git/repo.git'), isNull);
      expect(remoteWebOf('https://github.com/only-owner'), isNull);
    });
  });

  group('RemoteWeb links', () {
    final github = remoteWebOf('git@github.com:platform/repo-a.git')!;
    final gitlab = remoteWebOf('git@gitlab.com:group/sub/reader.git')!;
    final bitbucket = remoteWebOf('git@bitbucket.org:identity/users.git')!;

    test('the branch page keeps slashes and encodes the rest', () {
      expect(github.branchUrl('feat/link-to-branch'), 'https://github.com/platform/repo-a/tree/feat/link-to-branch');
      expect(github.branchUrl('fix/a#b c'), 'https://github.com/platform/repo-a/tree/fix/a%23b%20c');
      expect(gitlab.branchUrl('feat/x'), 'https://gitlab.com/group/sub/reader/-/tree/feat/x');
      expect(bitbucket.branchUrl('feat/x'), 'https://bitbucket.org/identity/users/branch/feat/x');
    });

    test('the new pull request page compares with the base when known', () {
      expect(
        github.newRequestUrl('feat/link-to-branch', base: 'release/0.10.0'),
        'https://github.com/platform/repo-a/compare/release/0.10.0...feat/link-to-branch?expand=1',
      );
      expect(github.newRequestUrl('feat/x'), 'https://github.com/platform/repo-a/compare/feat/x?expand=1');
      expect(
        gitlab.newRequestUrl('feat/x', base: 'main'),
        'https://gitlab.com/group/sub/reader/-/merge_requests/new?merge_request%5Bsource_branch%5D=feat%2Fx&merge_request%5Btarget_branch%5D=main',
      );
      expect(gitlab.newRequestUrl('feat/x'), 'https://gitlab.com/group/sub/reader/-/merge_requests/new?merge_request%5Bsource_branch%5D=feat%2Fx');
      expect(bitbucket.newRequestUrl('feat/x', base: 'main'), 'https://bitbucket.org/identity/users/pull-requests/new?source=feat%2Fx&dest=main');
    });

    test('names the host and what it calls a pull request', () {
      expect((github.hostName, github.request), ('GitHub', 'pull request'));
      expect((gitlab.hostName, gitlab.request), ('GitLab', 'merge request'));
      expect((bitbucket.hostName, bitbucket.request), ('Bitbucket', 'pull request'));
    });
  });

  group('baseBranchOf', () {
    test('drops the remote from a remote-tracking base', () {
      expect(baseBranchOf('origin/main'), 'main');
      expect(baseBranchOf('origin/release/0.10.0'), 'release/0.10.0');
      expect(baseBranchOf('main'), 'main');
      expect(baseBranchOf(''), '');
    });
  });

  group('openReleaseOf', () {
    test('the highest release branch on origin, compared as numbers', () {
      expect(
        openReleaseOf(['origin/main', 'origin/release/0.9.0', 'origin/release/0.10.0', 'origin/release/0.8.3', 'origin/feat/x']),
        'release/0.10.0',
      );
      expect(openReleaseOf(['origin/release/1.0.0', 'origin/release/0.99.99']), 'release/1.0.0');
      expect(openReleaseOf(['origin/release/0.10.2', 'origin/release/0.10.10']), 'release/0.10.10');
    });

    test('ignores other names and other remotes', () {
      expect(openReleaseOf(['origin/release/next', 'origin/release/1.2', 'origin/release/1.2.3-beta', 'upstream/release/9.0.0', 'origin/releases/2.0.0']), isNull);
    });

    test('none without release branches', () {
      expect(openReleaseOf(const []), isNull);
      expect(openReleaseOf(['origin/main', 'origin/feat/x']), isNull);
    });
  });

  group('branchLinksOf with release branches', () {
    const remote = 'git@github.com:platform/repo-a.git';
    const remotes = ['origin/main', 'origin/release/0.9.0', 'origin/release/0.10.0'];

    test('a pull request to create targets the open release', () {
      final links = branchLinksOf(remoteUrl: remote, branch: 'feat/x', base: 'origin/main', pushed: true, remoteBranches: remotes)!;
      expect(links.newRequestUrl, 'https://github.com/platform/repo-a/compare/release/0.10.0...feat/x?expand=1');
    });

    test('without a release branch it targets the base', () {
      final links = branchLinksOf(remoteUrl: remote, branch: 'feat/x', base: 'origin/main', pushed: true, remoteBranches: const ['origin/main'])!;
      expect(links.newRequestUrl, 'https://github.com/platform/repo-a/compare/main...feat/x?expand=1');
    });

    test('a release branch itself targets the default branch', () {
      final links = branchLinksOf(remoteUrl: remote, branch: 'release/0.10.0', base: 'origin/main', pushed: true, remoteBranches: remotes)!;
      expect(links.newRequestUrl, 'https://github.com/platform/repo-a/compare/main...release/0.10.0?expand=1');
      final older = branchLinksOf(remoteUrl: remote, branch: 'release/0.9.0', base: 'origin/main', pushed: true, remoteBranches: remotes)!;
      expect(older.newRequestUrl, 'https://github.com/platform/repo-a/compare/main...release/0.9.0?expand=1');
    });

    test('the default branch has no pull request to create, even with an open release', () {
      final links = branchLinksOf(remoteUrl: remote, branch: 'main', base: 'origin/main', pushed: true, remoteBranches: remotes)!;
      expect(links.newRequestUrl, isNull);
      expect(links.primaryUrl, 'https://github.com/platform/repo-a/tree/main');
    });
  });

  group('branchLinksOf', () {
    const remote = 'git@github.com:platform/repo-a.git';
    const pr = PullRequestInfo(number: 521, label: '#521', title: 't', author: 'a', branch: 'feat/x', url: 'https://github.com/platform/repo-a/pull/521');

    test('none until the branch is pushed', () {
      expect(branchLinksOf(remoteUrl: remote, branch: 'feat/x', base: 'origin/main', pushed: false), isNull);
    });

    test('none without a known host or a branch', () {
      expect(branchLinksOf(remoteUrl: 'git@git.acme.io:t/r.git', branch: 'feat/x', base: 'origin/main', pushed: true), isNull);
      expect(branchLinksOf(remoteUrl: '', branch: 'feat/x', base: 'origin/main', pushed: true), isNull);
      expect(branchLinksOf(remoteUrl: remote, branch: '', base: 'origin/main', pushed: true), isNull);
    });

    test('a pushed branch without a pull request offers to create one', () {
      final links = branchLinksOf(remoteUrl: remote, branch: 'feat/x', base: 'origin/main', pushed: true)!;
      expect(links.branchUrl, 'https://github.com/platform/repo-a/tree/feat/x');
      expect(links.pullRequest, isNull);
      expect(links.newRequestUrl, 'https://github.com/platform/repo-a/compare/main...feat/x?expand=1');
      expect(links.primaryUrl, links.newRequestUrl);
      expect(links.primaryLabel, 'Create pull request on GitHub');
    });

    test('an open pull request is the link', () {
      final links = branchLinksOf(remoteUrl: remote, branch: 'feat/x', base: 'origin/main', pushed: true, pullRequest: pr)!;
      expect(links.pullRequest, pr);
      expect(links.primaryUrl, 'https://github.com/platform/repo-a/pull/521');
      expect(links.primaryLabel, 'Open pull request #521 on GitHub');
    });

    test('a merged or closed pull request, or one without an address, is not', () {
      for (final other in [
        const PullRequestInfo(number: 1, label: '#1', title: 't', author: 'a', branch: 'feat/x', url: 'u', state: PrOpenState.merged),
        const PullRequestInfo(number: 2, label: '#2', title: 't', author: 'a', branch: 'feat/x', url: 'u', state: PrOpenState.closed),
        const PullRequestInfo(number: 3, label: '#3', title: 't', author: 'a', branch: 'feat/x'),
      ]) {
        final links = branchLinksOf(remoteUrl: remote, branch: 'feat/x', base: 'origin/main', pushed: true, pullRequest: other)!;
        expect(links.pullRequest, isNull, reason: other.label);
        expect(links.primaryUrl, links.newRequestUrl, reason: other.label);
      }
    });

    test('the default branch has no pull request to create', () {
      final links = branchLinksOf(remoteUrl: remote, branch: 'main', base: 'origin/main', pushed: true)!;
      expect(links.newRequestUrl, isNull);
      expect(links.primaryUrl, 'https://github.com/platform/repo-a/tree/main');
      expect(links.primaryLabel, 'Open main on GitHub');
    });
  });
}
