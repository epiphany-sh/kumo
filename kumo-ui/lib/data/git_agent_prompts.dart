/// What Kumo asks an agent to do with a commit, a release or a pull
/// request's review threads (from the Git view), as prompts. Pure
/// functions, so they can be tested as text.
library;

import 'dart:convert';

import 'pr_agent_prompts.dart';
import 'repo_history.dart';

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

// ---------------------------------------------------------------------------
// A commit
// ---------------------------------------------------------------------------

/// "Ask an agent" on a commit: what it does and why, and what's risky.
String commitExplainPrompt({required String repoName, required String sha, required String subject}) => [
      'Explain commit `$sha` (“$subject”) of $repoName to someone about to build on it.',
      'Read it: `git show --stat $sha`, then `git show $sha`.',
      'Say what it changes and why (from the message and the code), the files worth reading in the order to read them, and anything risky: behaviour that changed, missing tests, edge cases.',
      'Don’t change any file.',
    ].join('\n\n');

// ---------------------------------------------------------------------------
// Releases
// ---------------------------------------------------------------------------

/// How release notes are laid out.
enum ReleaseNotesStyle {
  changelog('Changelog', 'Sections: what’s new, fixes and the rest, one line per change.'),
  highlights('Highlights', 'Only what matters to people using it: a short intro and three to five bullets.'),
  both('Both', 'Highlights first, then the full changelog.');

  const ReleaseNotesStyle(this.label, this.hint);
  final String label;
  final String hint;
}

/// The jobs an agent can take on for a release, besides its notes.
enum ReleaseAgentJob {
  notes('Release notes'),
  explain('What changed'),
  announce('Announcement');

  const ReleaseAgentJob(this.label);
  final String label;
}

/// What the agent knows about the release it works on.
class ReleaseTarget {
  const ReleaseTarget({required this.repoName, required this.host, required this.tag, this.since, this.preRelease = false, this.skipped = const []});
  final String repoName;
  final String host;
  final String tag;

  /// The release it's compared with; null: the first release.
  final String? since;
  final bool preRelease;

  /// Tags between [since] and [tag] without notes of their own.
  final List<String> skipped;

  bool get first => since == null;
  String get range => first ? tag : '$since..$tag';
}

String _readRange(ReleaseTarget t) => t.first
    ? 'This is the first release of ${t.repoName}: there’s nothing before ${t.tag} to compare with. Read the project itself instead: the README, docs/, the build files (go.mod, package.json, Cargo.toml… whatever it has) and its main packages, then `git log --oneline ${t.tag}` for how it got here.'
    : 'Read what changed since ${t.since}: `git fetch --tags`, `git log --format=\'%h %s%n%b\' ${t.since}..${t.tag}` and `git diff --stat ${t.since}..${t.tag}`.'
        '${t.skipped.isEmpty ? '' : ' That includes ${t.skipped.join(', ')}, which ${t.skipped.length == 1 ? 'has' : 'have'} no notes of ${t.skipped.length == 1 ? 'its' : 'their'} own.'}'
        '${t.preRelease ? ' ${t.tag} is a pre-release: say so in a line on top, so nobody mistakes it for the latest.' : ''}';

/// The prompt that has an agent write [t]'s release notes into [draftPath]
/// (and, with [namePath], a short name for the release), for Kumo to show
/// the user before the release changes on the host.
String releaseNotesPrompt(
  ReleaseTarget t, {
  required String draftPath,
  String? namePath,
  ReleaseNotesStyle style = ReleaseNotesStyle.changelog,
  List<MergedPr> prs = const [],
  bool tickets = true,
  String? styleOf,
  bool thanks = true,
  String? currentNotes,
  String extra = '',
}) {
  final cli = switch (t.host) {
    'GH' => 'gh',
    'GL' => 'glab',
    _ => null,
  };
  final prWord = t.host == 'GL' ? 'merge requests' : 'pull requests';
  return [
    '${t.first ? 'Write the notes of ${t.tag}, the first release of ${t.repoName}.' : 'Write the release notes of ${t.tag} of ${t.repoName}.'} You are in its main checkout: don’t check anything out.',
    _readRange(t),
    if (prs.isNotEmpty)
      'The $prWord merged in it${cli == null ? '' : ' (read their descriptions with `$cli ${t.host == 'GL' ? 'mr' : 'pr'} view <number>` when a title isn’t enough)'}:\n'
          '${prs.map((p) => '- ${p.$1} ${p.$2} (${p.$3}${tickets && p.$4 != null ? ', ${p.$4}' : ''})').join('\n')}',
    if (styleOf != null) 'Keep the sections and tone of $styleOf’s notes: `${cli == 'gh' ? 'gh release view $styleOf' : cli == 'glab' ? 'glab release view $styleOf' : 'git tag -n99 $styleOf'}`.',
    if (currentNotes != null && currentNotes.trim().isNotEmpty) 'It already has these notes; keep what’s still true in them:\n\n${currentNotes.trim()}',
    t.first
        ? 'Write what ${t.repoName} is, what this first version does, and how to run it. ${style.hint}'
        : 'Style: ${style.hint}',
    if (thanks && prs.isNotEmpty) 'End by thanking who contributed, by their ${t.host == 'BB' ? 'names' : 'handles'}.',
    if (extra.trim().isNotEmpty) 'Also: ${extra.trim()}',
    'Write for people who use it, in the language of the commits. Name identifiers in backticks and link changes by their number. Don’t invent anything you didn’t read.',
    '${namePath == null ? 'Save the notes' : 'First save a short name for the release (two to four words, what matters most in it) to `$namePath`. Then save the notes'}'
        ', in Markdown, to `$draftPath`: only the notes, no title line and no preamble.',
    'Don’t change any other file, don’t tag, and don’t edit the release: I’ll check the draft in Kumo and update it from there. When the file is written, say “Done”.',
  ].join('\n\n');
}

/// "Explain what changed" and "Draft an announcement" for a release.
String releaseAgentPrompt(ReleaseAgentJob job, ReleaseTarget t) => switch (job) {
      ReleaseAgentJob.explain => [
          t.first ? 'Explain ${t.repoName} as of ${t.tag}, its first release, to someone joining the team.' : 'Explain what changed in ${t.repoName} from ${t.since} to ${t.tag}.',
          _readRange(t),
          t.first ? 'Say what it does, how it’s laid out and how to run it.' : 'Group it by what it means for people using it, then list anything risky to deploy (migrations, flags, config).',
          'Don’t change any file.',
        ].join('\n\n'),
      ReleaseAgentJob.announce => [
          'Draft a short Slack message announcing ${t.tag} of ${t.repoName} to the team.',
          _readRange(t),
          'Three to six lines: what’s new that people will notice, anything they need to do, and a link placeholder <release link>. No headings.',
          'Don’t change any file and don’t post it: I’ll send it.',
        ].join('\n\n'),
      ReleaseAgentJob.notes => throw ArgumentError('Use releaseNotesPrompt'),
    };

// ---------------------------------------------------------------------------
// Review threads
// ---------------------------------------------------------------------------

/// What happens to the threads once the agent is done.
enum ResolveMode {
  replyAndResolve('Reply and resolve', 'Posts each reply and resolves the thread'),
  replyOnly('Reply only', 'Reviewers resolve their own threads'),
  codeOnly('Just the code', 'Commits only: nothing is posted');

  const ResolveMode(this.label, this.hint);
  final String label;
  final String hint;
}

/// The prompt that has an agent work through [threads] of [t]'s pull
/// request: change the code where a thread asks for it, commit without
/// pushing, and write what it did to [answersPath] as JSON for Kumo.
String resolveCommentsPrompt(PrAgentTarget t, List<ReviewThread> threads, {required String answersPath, ResolveMode mode = ResolveMode.replyAndResolve}) {
  final list = [
    for (final th in threads) '- [${th.id}] ${th.author} on `${th.where}`: ${th.body.replaceAll('\n', ' ')}',
  ].join('\n');
  final example = const JsonEncoder.withIndent('  ').convert([
    {'thread': threads.isEmpty ? 't1' : threads.first.id, 'changed': 'one line on what you changed, or "" for none', 'commit': 'short sha, or ""', 'reply': 'what to answer the reviewer'},
  ]);
  return [
    '${_cap(t.what)} “${t.pr.title}” of ${t.repoName} has these open review threads:\n$list',
    t.inWorktree ? 'You are in its worktree, on `${t.pr.branch}`.' : 'Check out `${t.pr.branch}` first (`git switch ${t.pr.branch}`): you are in the main checkout.',
    'Go through them in order. When a thread asks for a change and it’s right, make it, run the tests that cover it, and commit with a message that says what it fixes. When it’s a question, or you disagree, don’t change code: answer it.',
    'Commit, but don’t push, and don’t post or resolve anything on the ${t.host == 'GL' ? 'merge request' : 'pull request'}: I’ll check your work in Kumo and ${mode == ResolveMode.codeOnly ? 'push it' : 'post the replies'} from there.',
    if (mode != ResolveMode.codeOnly) 'Write each reply as the author of the ${t.host == 'GL' ? 'merge request' : 'pull request'} would: short, specific, naming the commit when there is one.',
    'When you’re done, save what you did for each thread to `$answersPath` as JSON, one entry per thread, like:\n```json\n$example\n```\nThen say “Done”.',
  ].join('\n\n');
}

/// One thread's outcome, as the agent wrote it to the answers file.
class ThreadAnswer {
  const ThreadAnswer({required this.thread, this.changed = '', this.commit = '', this.reply = ''});
  final String thread;
  final String changed;
  final String commit;
  final String reply;

  /// Reads the agent's answers file; entries it can't read are skipped.
  static List<ThreadAnswer> parse(String json) {
    final Object? data;
    try {
      data = jsonDecode(json);
    } on FormatException {
      return const [];
    }
    if (data is! List) return const [];
    return [
      for (final e in data)
        if (e is Map && e['thread'] is String)
          ThreadAnswer(
            thread: e['thread'] as String,
            changed: e['changed'] is String ? e['changed'] as String : '',
            commit: e['commit'] is String ? e['commit'] as String : '',
            reply: e['reply'] is String ? e['reply'] as String : '',
          ),
    ];
  }
}
