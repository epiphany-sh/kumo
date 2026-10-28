import 'package:flutter/material.dart';

import '../app/app_state.dart';
import '../data/ci_hosts_source.dart';
import '../data/pipelines_source.dart';
import '../theme/kumo_theme.dart';
import '../widgets/controls.dart';

/// What a host's token needs, in one line.
String _tokenHelp(CiProvider provider) => switch (provider) {
      CiProvider.githubActions =>
        'A fine-grained token with Actions: read (read and write to re-run jobs), or a classic one with the “repo” scope. GitHub › Settings › Developer settings.',
      CiProvider.gitlabCi => 'A personal access token with “read_api” (“api” to retry pipelines). GitLab › Preferences › Access tokens.',
      CiProvider.bitbucketPipelines =>
        'An API token as email:token with Pipelines read (write to re-run), or a repository access token.',
    };

/// Settings › Repositories: one token per host of the workspace's
/// repositories, for pipelines. Tokens go to the Keychain through the
/// daemon; GitHub hosts can sign in with the GitHub CLI (`gh`) instead.
class HostTokensPanel extends StatefulWidget {
  const HostTokensPanel({super.key});

  @override
  State<HostTokensPanel> createState() => _HostTokensPanelState();
}

class _HostTokensPanelState extends State<HostTokensPanel> {
  List<CiHostInfo>? _hosts;
  String? _error;
  String? _open;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final hosts = await AppScope.read(context).ciHosts.list();
      if (!mounted) return;
      setState(() {
        _hosts = hosts;
        _error = null;
      });
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final hosts = _hosts;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (hosts == null && _error == null) Text('Looking at your repositories…', style: sans(12.5, color: c.text3)),
      if (hosts != null && hosts.isEmpty)
        Text('None of the repositories in your namespaces is on GitHub, GitLab or Bitbucket yet.', style: sans(12.5, color: c.text3)),
      for (final h in hosts ?? const <CiHostInfo>[]) ...[
        const SizedBox(height: 8),
        _HostCard(
          key: ValueKey(h.host),
          host: h,
          expanded: _open == h.host,
          onToggle: () => setState(() => _open = _open == h.host ? null : h.host),
          onSaved: (saved) => setState(() {
            _hosts = [for (final x in _hosts!) if (x.host == saved.host) saved else x];
            _open = null;
          }),
        ),
      ],
      if (_error != null) ...[
        const SizedBox(height: 10),
        Text(_error!, style: sans(12, color: c.err)),
      ],
    ]);
  }
}

class _HostCard extends StatelessWidget {
  const _HostCard({super.key, required this.host, required this.expanded, required this.onToggle, required this.onSaved});
  final CiHostInfo host;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<CiHostInfo> onSaved;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final (status, color) = host.hasToken
        ? ('Token saved', c.ok)
        : host.usesGh
            ? (host.ghAccount.isEmpty ? 'Signed in with gh' : 'Signed in with gh as ${host.ghAccount}', c.ok)
            : ('Not connected', c.warn);
    final repos = host.repos.length == 1 ? host.repos.first : '${host.repos.length} repositories · ${host.repos.take(2).join(', ')}${host.repos.length > 2 ? '…' : ''}';
    return Container(
      decoration: BoxDecoration(color: c.codeBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: expanded ? c.accSoft : c.paneBorder)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            TagChip(host.provider.host),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(host.host, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(13.5, weight: FontWeight.w600, color: c.text)),
                Text('${host.provider.label} · $repos', maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11.5, color: c.text3)),
              ]),
            ),
            const SizedBox(width: 10),
            Dot(color),
            const SizedBox(width: 6),
            Text(status, style: sans(12, weight: FontWeight.w500, color: color)),
            const SizedBox(width: 10),
            KButton(label: expanded ? 'Done' : (host.hasToken || host.usesGh ? 'Change' : 'Connect'), height: 30, fontSize: 12.5, onTap: onToggle),
          ]),
        ),
        if (expanded)
          Container(
            decoration: BoxDecoration(border: Border(top: BorderSide(color: c.divider))),
            child: _TokenForm(host: host, onSaved: onSaved),
          ),
      ]),
    );
  }
}

/// Paste, test, save or remove a host's token.
class _TokenForm extends StatefulWidget {
  const _TokenForm({required this.host, required this.onSaved});
  final CiHostInfo host;
  final ValueChanged<CiHostInfo> onSaved;

  @override
  State<_TokenForm> createState() => _TokenFormState();
}

class _TokenFormState extends State<_TokenForm> {
  final _token = TextEditingController();
  bool _busy = false;
  CiHostTest? _test;
  String? _error;

  @override
  void dispose() {
    _token.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function(CiHostsSource hosts) action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action(AppScope.read(context).ciHosts);
    } on Object catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _check() => _run((hosts) async {
        final test = await hosts.test(widget.host.host, token: _token.text.trim());
        if (mounted) setState(() => _test = test);
      });

  Future<void> _save(String token) => _run((hosts) async {
        final saved = await hosts.saveToken(widget.host.host, token);
        widget.onSaved(saved);
      });

  /// gh signs in in a terminal (browser and one-time code); the daemon
  /// notices when it's done and the pipelines come in on their own.
  Future<void> _signInWithGh() => _run((hosts) async {
        final terminal = await hosts.signInWithGh(widget.host.host);
        if (!mounted) return;
        final s = AppScope.read(context);
        Navigator.of(context).maybePop();
        s.openTerminal(terminal, title: 'gh · sign in');
      });

  /// The GitHub CLI way, first: no token to create or paste.
  Widget _cli(BuildContext context) {
    final c = context.c;
    final h = widget.host;
    final Widget body;
    if (h.usesGh) {
      body = Text(
        h.ghAccount.isEmpty ? 'Kumo uses the GitHub CLI’s sign-in.' : 'Kumo uses the GitHub CLI’s sign-in as ${h.ghAccount}.',
        style: sans(12, color: c.ok),
      );
    } else if (h.hasToken) {
      body = Text('The saved token is used. Remove it to use the GitHub CLI’s sign-in instead.', style: sans(12, color: c.text3));
    } else if (h.ghAvailable) {
      body = Row(children: [
        Expanded(child: Text('Signs in through your browser in a terminal; nothing to paste. Reads and re-runs pipelines with your GitHub account.', style: sans(12, color: c.text3))),
        const SizedBox(width: 10),
        KButton.primary(label: 'Sign in with GitHub CLI', height: 30, fontSize: 12.5, onTap: _busy ? null : _signInWithGh),
      ]);
    } else {
      body = Text('Install the GitHub CLI to sign in without a token: brew install gh', style: sans(12, color: c.text3));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('GitHub CLI', style: sans(11, color: c.text3)),
      const SizedBox(height: 4),
      body,
      const SizedBox(height: 14),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final h = widget.host;
    final test = _test;
    final problem = test?.problem;
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (h.provider == CiProvider.githubActions) _cli(context),
        Text(h.provider == CiProvider.githubActions ? 'Or an access token' : 'Access token', style: sans(11, color: c.text3)),
        const SizedBox(height: 4),
        Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(10), border: Border.all(color: c.chipBorder)),
          child: TextField(
            controller: _token,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (_) => setState(() => _test = null),
            style: mono(12, color: c.text),
            cursorColor: c.acc,
            decoration: InputDecoration.collapsed(
              hintText: h.hasToken ? '•••••••• saved · paste to replace' : (h.usesGh ? 'Optional: gh’s sign-in is used meanwhile' : 'Paste your token'),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(_tokenHelp(h.provider), style: sans(11.5, color: c.text3)),
        if (test != null) ...[
          const SizedBox(height: 8),
          if (problem == null)
            Text(test.message, style: sans(12, color: c.ok))
          else ...[
            Text(describeCiProblem(problem, h.provider).$1, style: sans(12, weight: FontWeight.w600, color: c.err)),
            if (problem.missingScope.isNotEmpty) Text('Needs “${problem.missingScope}”.', style: sans(11.5, color: c.text2)),
            if (problem.detail.isNotEmpty) Text(problem.detail, style: mono(11, color: c.text3)),
          ],
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: sans(12, color: c.err)),
        ],
        const SizedBox(height: 12),
        Row(children: [
          if (h.hasToken)
            KButton(label: 'Remove token', kind: KButtonKind.ghost, height: 30, fontSize: 12.5, onTap: _busy ? null : () => _save('')),
          const Spacer(),
          KButton(label: 'Test', height: 30, fontSize: 12.5, onTap: _busy || (_token.text.trim().isEmpty && !h.hasToken && !h.usesGh) ? null : _check),
          const SizedBox(width: 8),
          KButton.primary(label: 'Save', height: 30, fontSize: 12.5, onTap: _busy || _token.text.trim().isEmpty ? null : () => _save(_token.text.trim())),
        ]),
      ]),
    );
  }
}
