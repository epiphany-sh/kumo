import 'dart:io' show File;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../engine/engine_scope.dart';
import '../engine/generated/kumo/v1/kumo.pb.dart' show ForgetHistoryRequest;
import '../platform/app_icon.dart';
import '../platform/pasteboard.dart';
import '../platform/os/host_os.dart';
import '../terminal/command_marks.dart';
import '../theme/kumo_theme.dart';
import '../theme/palette.dart';
import '../widgets/profile_tile.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';
import '../widgets/kumo_mark.dart';
import 'agent_settings.dart';
import 'docs_settings.dart';
import 'host_settings.dart';
import 'task_settings.dart';
import 'workspace_settings.dart';
import 'your_lines_settings.dart';

enum SettingsTab {
  general('General', Icons.settings_outlined),
  appearance('Appearance', Icons.palette_outlined),
  terminal('Terminal', Icons.terminal_rounded),
  shortcuts('Shortcuts', Icons.keyboard_outlined),
  workspaces('Workspaces', Icons.layers_outlined),
  ai('AI agents', Icons.auto_awesome_outlined),
  tickets('Tasks', Icons.task_alt_rounded),
  repos('Repositories', Icons.account_tree_outlined),
  docs('Docs', Icons.menu_book_outlined);

  const SettingsTab(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Settings window (⌘, or the gear in the sidebar): app settings on the
/// left of the toolbar, integrations on the right. What changes look or
/// layout applies at once; the rest is saved for kumod to pick up.
Future<void> showSettingsDialog(BuildContext context, {SettingsTab initial = SettingsTab.general}) {
  final c = context.c;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close settings',
    barrierColor: c.isDark ? const Color(0x80000000) : const Color(0x38141428),
    transitionDuration: const Duration(milliseconds: 140),
    transitionBuilder: (context, anim, _, child) => FadeTransition(
      opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
      child: ScaleTransition(scale: Tween(begin: 0.985, end: 1.0).animate(CurvedAnimation(parent: anim, curve: Curves.easeOut)), child: child),
    ),
    pageBuilder: (context, _, __) => Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
        child: Material(type: MaterialType.transparency, child: SettingsDialog(initial: initial)),
      ),
    ),
  );
}

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({super.key, this.initial = SettingsTab.general});
  final SettingsTab initial;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late SettingsTab _tab = widget.initial;

  void _close() => Navigator.of(context).maybePop();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final size = MediaQuery.sizeOf(context);
    final width = math.min(1060.0, size.width - 48);
    final height = math.min(872.0, size.height - 64);
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): _close},
      child: FocusScope(
        autofocus: true,
        child: Semantics(
          scopesRoute: true,
          explicitChildNodes: true,
          namesRoute: true,
          label: 'Settings',
          child: SizedBox(
            width: width,
            height: height,
            child: GlassOverlay(
              radius: 24,
              padding: EdgeInsets.zero,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SizedBox(
                  height: 44,
                  child: Stack(alignment: Alignment.center, children: [
                    Positioned(
                      left: 18,
                      child: Row(children: [
                        KPressable(
                          onTap: _close,
                          semanticLabel: 'Close settings',
                          tooltip: 'Close (Esc)',
                          builder: (context, hover, focus) => Container(
                            width: 12,
                            height: 12,
                            decoration: const BoxDecoration(color: Color(0xFFFF5F57), shape: BoxShape.circle),
                            child: hover || focus ? const Icon(Icons.close_rounded, size: 9, color: Color(0x99000000)) : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        for (var k = 0; k < 2; k++) ...[
                          Container(width: 12, height: 12, decoration: BoxDecoration(color: c.tile, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                        ],
                      ]),
                    ),
                    Text(_tab.label, style: sans(13, weight: FontWeight.w600, color: c.text2)),
                  ]),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.divider))),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      for (final t in SettingsTab.values) ...[
                        if (t == SettingsTab.ai) Container(width: 1, height: 34, margin: const EdgeInsets.symmetric(horizontal: 8), color: c.divider),
                        _TabButton(tab: t, selected: t == _tab, onTap: () => setState(() => _tab = t)),
                        const SizedBox(width: 2),
                      ],
                    ]),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(28, 22, 28, 32),
                    children: [
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 800),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: _content(context)),
                        ),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }


  // ------------------------------------------------------------ content

  List<Widget> _content(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final page = _page(context, s);
    return [
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(page.heading, style: sans(20, weight: FontWeight.w600, color: c.text, letterSpacing: -0.2)),
            const SizedBox(height: 4),
            Text(page.intro, style: sans(12.5, color: c.text3, height: 1.45)),
          ]),
        ),
      ]),
      if (page.scoped) ...[const SizedBox(height: 14), _ScopeNote(note: page.scopeNote, onManage: () => setState(() => _tab = SettingsTab.workspaces))],
      if (page.custom != null) page.custom!,
      for (final sec in page.sections) ...[const SizedBox(height: 16), _Section(title: sec.$1, rows: sec.$2)],
    ];
  }

  // ------------------------------------------------------------ pages

  _Page _page(BuildContext context, AppState s) {
    switch (_tab) {
      case SettingsTab.general:
        return _Page('General', 'How Kumo starts, updates and where it keeps its data.', custom: const _About(), sections: [
          ('Layout', [
            _SegRow(
              label: 'Side panel position',
              desc: 'Where the Files · Widgets · Source control panel sits in the Terminal view.',
              options: const ['Left', 'Right'],
              value: s.sidePanelRight ? 'Right' : 'Left',
              onChanged: (v) => s.sidePanelRight = v == 'Right',
            ),
            _ToggleRow(label: 'Show the side panel when Kumo opens', desc: 'Hide or show it anytime with ⌥⌘B.', value: s.sidePanelOnLaunch, onChanged: (v) => s.sidePanelOnLaunch = v),
            _ToggleRow(
              label: 'Remember folded repositories',
              desc: 'Repositories you fold in the sidebar stay folded the next time Kumo opens. Off, they all open expanded.',
              value: s.rememberSidebarFolds,
              onChanged: (v) => s.rememberSidebarFolds = v,
            ),
          ]),
          ('Startup', [
            _toggle(s, 'general.login', 'Open Kumo at login', null, false),
            _select(s, 'general.workspace', 'Default workspace', 'Namespace selected when the app opens.', const ['Last used', 'platform', 'identity'], 'Last used'),
            _toggle(s, 'general.reopen', 'Reopen terminals and agents from last session', 'kumod keeps them running while the app is closed.', true),
          ]),
          ('Updates & privacy', [
            _seg(s, 'general.channel', 'Update channel', null, const ['Stable', 'Beta'], 'Stable'),
            _toggle(s, 'general.autoUpdate', 'Download updates automatically', null, true),
            _toggle(s, 'general.crash', 'Send anonymous crash reports', 'No code, prompts or file contents ever leave your machine this way.', true),
          ]),
        ]);
      case SettingsTab.appearance:
        return _Page('Appearance', 'Liquid Glass themes, translucency, and how the lines you run look in the terminal.', sections: [
          ('Theme', [
            _Row(label: 'Theme', control: _ThemePicker(value: s.mode, onChanged: (m) => s.mode = m)),
            if (AppIcons.choosable)
              _Row(
                label: 'App icon',
                desc: AppIcons.canMakeOwn ? '${hostOs.appIconPlaces} Any image can be yours: a square one gets rounded corners.' : hostOs.appIconPlaces,
                control: _AppIconPicker(state: s),
              ),
            _Row(
              label: 'Glass translucency',
              desc: 'How much of the desktop shows through panels.',
              control: _PercentSlider(value: s.translucency, onChanged: (v) => s.translucency = v),
            ),
            _ToggleRow(
              label: 'Demo wallpaper',
              desc: 'Paint a backdrop instead of the desktop (when native translucency is off).',
              value: s.demoWallpaper,
              onChanged: (_) => s.toggleDemoWallpaper(),
            ),
          ]),
          ('Your lines in the terminal', _yourLinesRows(s)),
          ('Files', [
            _SegRow(
              label: 'File icons',
              desc: 'Colored per file type (Material Icon Theme), or plain gray.',
              options: const ['Colored', 'Simple'],
              value: s.colorFileIcons ? 'Colored' : 'Simple',
              onChanged: (v) => s.colorFileIcons = v == 'Colored',
            ),
          ]),
        ]);
      case SettingsTab.terminal:
        return _Page('Terminal', 'Shell, font and keyboard behaviour of every terminal pane.', sections: [
          ('Shell', [
            _select(s, 'terminal.shell', 'Shell', 'Login shell for new tabs (⌘T) and splits.', hostOs.shellChoices, hostOs.defaultShellChoice),
            _text(s, 'terminal.cwd', 'Start in', 'For tabs opened outside a worktree.', '~', mono: true),
            _select(s, 'terminal.scrollback', 'Scrollback', null, const ['5,000 lines', '10,000 lines', '50,000 lines', 'Unlimited'], '10,000 lines'),
          ]),
          ('Text & cursor', [
            _select(s, 'terminal.fontSize', 'Font size', null, const ['11', '12', '13', '14', '15'], '12'),
            _seg(s, 'terminal.cursor', 'Cursor', null, const ['Block', 'Bar', 'Underline'], 'Block'),
            _toggle(s, 'terminal.blink', 'Blinking cursor', null, false),
          ]),
          ('Keyboard & mouse', [
            _toggle(s, 'terminal.optionMeta', 'Use ⌥ as Meta', 'Needed for word jumps in emacs/readline; off keeps ⌥ for special characters.', true),
            _toggle(s, 'terminal.copyOnSelect', 'Copy on select', null, false),
            _toggle(s, 'terminal.confirmClose', 'Ask before closing a pane with a running process', null, true),
          ]),
          ('Commands you run', [
            _toggle(
              s,
              YourLines.keyRemember,
              'Remember them',
              'Per repository, shared by its worktrees, in this workspace. A command you start with a space isn’t kept. Works in zsh, bash and fish; applies to new terminals.',
              true,
            ),
            _toggle(
              s,
              YourLines.keySuggest,
              'Suggest as you type',
              'The rest of a command you ran shows in gray: → takes it, ⌥→ its next word. Hidden when another tool (zsh-autosuggestions) already suggests.',
              true,
            ),
            const _Row(
              label: 'Forget them',
              desc: 'Every command remembered in this workspace. The history of one repository: ⌘Y in a terminal (Ctrl+Shift+Y on Windows and Linux).',
              control: _ForgetCommands(),
            ),
          ]),
        ]);
      case SettingsTab.shortcuts:
        return _Page('Shortcuts', 'Keyboard shortcuts across Kumo.', sections: [
          ('Terminal', const [
            _KbdRow('New tab', ['⌘', 'T']),
            _KbdRow('Split right', ['⌘', 'D']),
            _KbdRow('Split down', ['⇧', '⌘', 'D']),
            _KbdRow('Close pane', ['⌘', 'W']),
            _KbdRow('Previous command you ran', ['⌘', '↑']),
            _KbdRow('Next command you ran', ['⌘', '↓']),
            _KbdRow('Command history', ['⌘', 'Y']),
            _KbdRow('Show / hide side panel', ['⌥', '⌘', 'B']),
          ]),
          ('Workspace', const [
            _KbdRow('Terminal (Home) · Agents · Tasks · Git · Docs', ['⌘', '1…5']),
            _KbdRow('Settings', ['⌘', ',']),
            _KbdRow('New worktree', ['⇧', '⌘', 'N']),
            _KbdRow('Show / hide sidebar', ['⌥', '⌘', 'S']),
            _KbdRow('Cycle theme', ['⇧', '⌘', 'L']),
            _KbdRow('Switch to workspace 1…9', ['⌃', '⌘', '1…9']),
          ]),
          ('Source control', const [
            _KbdRow('Commit', ['⌘', '↩']),
          ]),
        ]);
      case SettingsTab.workspaces:
        return _Page(
          'Workspaces',
          'A workspace keeps one context apart from another: its own Git hosts and tokens, task sources, knowledge bases, agents’ sign-ins, namespaces and worktrees. Switch from the top of the sidebar, or with ⌃⌘1…9; the others keep running.',
          custom: WorkspacesSettingsPanel(
            onOpenTab: (t) => setState(() => _tab = SettingsTab.values.firstWhere((x) => x.name == t, orElse: () => SettingsTab.workspaces)),
          ),
        );
      case SettingsTab.ai:
        return _Page(
          'AI agents',
          'Coding agents Kumo can run in your worktrees, with your own sign-in: Kumo never proxies models. Each one runs in its own terminal. Optional: everything else works without them.',
          scopeNote: 'Agents sign in here with this workspace’s accounts; another workspace connects its own.',
          custom: const AgentSettingsPanel(),
          sections: [
            ('Defaults', [
              _toggle(s, 'ai.ownWorktree', 'Give every agent its own worktree', 'Agents never share a checkout, so they can’t step on each other.', true),
              _toggle(s, 'ai.notify', 'Notify me when an agent needs input', null, true),
            ]),
            ('Plan usage', [
              _toggle(
                s,
                'usage.sidebar',
                'Show what’s left in the sidebar',
                s.usage.supported
                    ? 'One row per agent with its tightest limit: Claude Code and Codex count 5-hour and weekly windows, Copilot premium requests per month. Read from each account with the agent’s own sign-in, even when none is running.'
                    : 'Not available yet: this version of Kumo can’t read the agents’ usage. The setting applies once it can.',
                true,
              ),
              _seg(s, 'usage.as', 'Show', null, const ['Left', 'Used'], 'Left'),
              _select(s, 'usage.rows', 'Rows in the sidebar', 'Agents in the order above, the default first. Past that, the last row becomes “+N more”, which still says when a folded one runs low.', const ['4', '6', 'All'], '4'),
              _select(s, 'usage.warn', 'Highlight a limit when less than', 'It turns amber, then red when it’s nearly spent.', const ['25% is left', '10% is left', 'Never'], '25% is left'),
            ]),
          ],
        );
      case SettingsTab.tickets:
        return _Page(
          'Tasks',
          'Where your tasks come from. Kumo keeps them on this Mac so Tasks opens instantly, re-reads them in the background and writes status changes back. Start a worktree with an agent from any of them.',
          scopeNote: 'These task sources and their tokens aren’t visible from other workspaces.',
          custom: const TaskSourceSettingsPanel(),
        );
      case SettingsTab.repos:
        return _Page(
          'Repositories',
          'Tokens for the hosts of your repositories, so the Pipelines widget shows their CI. One per host, kept in the macOS Keychain.',
          scopeNote: 'Git hosts, tokens and the folders below belong to this workspace. Repos of other workspaces never use them.',
          custom: const HostTokensPanel(),
          sections: [
            ('Where code lives', [
              _text(s, 'repos.clone', 'Clone into', null, '~/dev', mono: true),
              _text(s, 'repos.worktrees', 'Worktrees in', 'One folder per worktree, outside the main checkout.', '~/wt/{repo}/{key}', mono: true),
              _toggle(s, 'repos.prune', 'Remove a worktree after its PR merges', 'Asks first if it has uncommitted changes.', true),
            ]),
            ('Git', [
              _select(s, 'repos.fetch', 'Fetch remotes', null, const ['Every 5 minutes', 'Every 15 minutes', 'Manually'], 'Every 5 minutes'),
              _toggle(s, 'repos.sign', 'Sign commits', 'Uses your git config (gpg / ssh).', false),
            ]),
          ],
        );
      case SettingsTab.docs:
        return _Page(
          'Docs',
          'Knowledge bases agents can read for context: specs, ADRs, runbooks. Docs reads them through your task sources, so there is nothing else to connect.',
          scopeNote: 'Knowledge bases belong to this workspace; agents here only read these.',
          custom: const DocsSourcesPanel(),
        );
    }
  }

  /// Marks on what you ran and the pinned command (see [YourLines]).
  List<Widget> _yourLinesRows(AppState s) {
    final yl = s.yourLines.value;
    final sticky = _toggle(
      s,
      YourLines.keySticky,
      'Keep the command on top',
      'While its output scrolls, the line you ran stays pinned at the top of the pane until you run the next one.',
      true,
    );
    final on = _toggle(
      s,
      YourLines.keyOn,
      'Mark what you ran',
      'A bar, and a faint band if you want, on the commands you typed. Output isn’t touched. Works in zsh, bash and fish.',
      true,
    );
    if (!yl.marks) return [on, sticky];
    final own = s.setting<String>(YourLines.keyLightMode, 'auto') == 'own';
    final auto = forLightTerminal(yl.dark, terminalBackground(KumoPalette.light));
    final light = yl.colorFor(KumoPalette.light);
    String withNote(String desc, String? note) => note == null ? desc : '$desc $note';
    return [
      on,
      _SegRow(
        label: 'Style',
        desc: 'Bar only is the quietest.',
        options: const ['Bar + band', 'Bar only'],
        value: yl.band ? 'Bar + band' : 'Bar only',
        onChanged: (v) => s.setSetting(YourLines.keyStyle, v == 'Bar only' ? 'bar' : 'barBand'),
      ),
      _Row(
        label: 'Color on dark terminals',
        desc: withNote('Dark theme, and Hybrid (its terminal is dark). Failed commands stay red.', lowContrastNote(yl.dark, KumoPalette.dark)),
        control: MarkSwatches(label: 'Color on dark terminals', presets: yourLinesPresets, value: yl.dark, onChanged: (c) => s.setSetting(YourLines.keyDark, hexOf(c))),
      ),
      _SegRow(
        label: 'On light terminals',
        desc: own ? 'Its own color, for when the darker version of yours doesn’t look right.' : 'Same hue, darkened until it reads on white: ${hexOf(auto)}.',
        options: const ['Auto', 'Own color'],
        value: own ? 'Own color' : 'Auto',
        onChanged: (v) => s.setSetting(YourLines.keyLightMode, v == 'Own color' ? 'own' : 'auto'),
      ),
      if (own)
        _Row(
          label: 'Color on light terminals',
          desc: withNote('Presets are the dark ones, darkened.', lowContrastNote(light, KumoPalette.light)),
          control: MarkSwatches(label: 'Color on light terminals', presets: lightPresets(), value: light, onChanged: (c) => s.setSetting(YourLines.keyLight, hexOf(c))),
        ),
      if (yl.band)
        _Row(
          label: 'Band strength',
          desc: 'How much of the color fills the line.',
          control: _StepSlider(label: 'Band strength', value: yl.bandAlpha * 100, min: 2, max: 30, unit: '%', onChanged: (v) => s.setSetting(YourLines.keyBand, v)),
        ),
      _Row(
        label: 'Bar width',
        control: _StepSlider(label: 'Bar width', value: yl.bar, min: 1, max: 5, unit: ' px', onChanged: (v) => s.setSetting(YourLines.keyBar, v)),
      ),
      _toggle(s, YourLines.keyMeta, 'Exit code and time', 'On a command that failed or that you stopped, and the time when it took 10 seconds or more.', true),
      sticky,
      _Row(label: 'Preview', desc: 'Both terminals, as you tune them. Hybrid uses the dark one.', control: YourLinesPreview(lines: yl)),
    ];
  }

  // Rows backed by AppState.setting / setSetting (persisted).
  Widget _toggle(AppState s, String key, String label, String? desc, bool fallback) =>
      _ToggleRow(label: label, desc: desc, value: s.setting<bool>(key, fallback), onChanged: (v) => s.setSetting(key, v));

  Widget _select(AppState s, String key, String label, String? desc, List<String> options, String fallback) {
    final v = s.setting<String>(key, fallback);
    return _Row(label: label, desc: desc, control: _Dropdown(value: options.contains(v) ? v : fallback, options: options, onChanged: (x) => s.setSetting(key, x)));
  }

  Widget _seg(AppState s, String key, String label, String? desc, List<String> options, String fallback) =>
      _SegRow(label: label, desc: desc, options: options, value: s.setting<String>(key, fallback), onChanged: (v) => s.setSetting(key, v));

  Widget _text(AppState s, String key, String label, String? desc, String fallback, {bool mono = false}) => _Row(
        label: label,
        desc: desc,
        control: _TextSetting(key: ValueKey(key), value: s.setting<String>(key, fallback), mono: mono, onChanged: (v) => s.setSetting(key, v)),
      );
}

/// The app's mark and name at the top of General.
class _About extends StatelessWidget {
  const _About();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            // The app icon's tile: the mark on near-black, in every theme.
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF1F222A), Color(0xFF0A0B0E)]),
              border: Border.all(color: const Color(0x14FFFFFF)),
            ),
            child: const KumoMark(size: 38, semanticLabel: null),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('kumo', style: sans(18, weight: FontWeight.w600, color: c.text, letterSpacing: -0.6)),
              const SizedBox(height: 2),
              Text('Terminals, coding agents, worktrees, tasks and docs in one window.', style: sans(12.5, color: c.text3, height: 1.4)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _Page {
  _Page(this.heading, this.intro, {this.sections = const [], this.custom, this.scopeNote = ''});
  final String heading;
  final String intro;

  /// What makes this page the current workspace's own; empty: app-wide.
  final String scopeNote;
  bool get scoped => scopeNote.isNotEmpty;
  final List<(String, List<Widget>)> sections;

  /// A page-specific panel shown before the sections (AI agents).
  final Widget? custom;
}

// ------------------------------------------------------------ pieces

class _TabButton extends StatelessWidget {
  const _TabButton({required this.tab, required this.selected, required this.onTap});
  final SettingsTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return KPressable(
      onTap: onTap,
      semanticLabel: tab.label,
      selected: selected,
      builder: (context, hover, focus) => Container(
        width: 88,
        height: 56,
        decoration: selected
            ? chipDecoration(c, radius: 12, fill: c.tabActive)
            : BoxDecoration(color: hover || focus ? c.tile : null, borderRadius: BorderRadius.circular(12)),
        child: Stack(children: [
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(tab.icon, size: 20, color: selected ? c.text : c.text2),
              const SizedBox(height: 5),
              Text(tab.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: sans(11.5, weight: FontWeight.w500, color: selected ? c.text : c.text2)),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// "Only for <workspace>": a settings page that belongs to the current
/// workspace, with the way to the others.
class _ScopeNote extends StatelessWidget {
  const _ScopeNote({required this.note, required this.onManage});
  final String note;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final p = s.profile;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: c.tile, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        ProfileTile(profile: p, size: 26),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: 'Only for ${p.displayName}. ', style: sans(12, weight: FontWeight.w600, color: c.text)),
              TextSpan(text: note, style: sans(12, color: c.text2)),
            ]),
            style: const TextStyle(height: 1.45),
          ),
        ),
        const SizedBox(width: 10),
        KButton(label: 'Workspaces…', height: 30, fontSize: 12.5, onTap: onManage),
      ]),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});
  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      decoration: BoxDecoration(color: c.codeBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: c.paneBorder)),
      clipBehavior: Clip.antiAlias,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 10), child: Text(title.toUpperCase(), style: microLabel(c))),
        ...rows,
      ]),
    );
  }
}

/// label + description on the left, control on the right.
class _Row extends StatelessWidget {
  const _Row({required this.label, required this.control, this.desc});
  final String label;
  final String? desc;
  final Widget control;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.divider))),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: sans(13, weight: FontWeight.w500, color: c.text)),
            if (desc != null) ...[const SizedBox(height: 2), Text(desc!, style: sans(11.5, color: c.text3, height: 1.4))],
          ]),
        ),
        const SizedBox(width: 16),
        control,
      ]),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.label, required this.value, required this.onChanged, this.desc});
  final String label;
  final String? desc;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => _Row(label: label, desc: desc, control: KSwitch(value: value, onChanged: onChanged, label: label));
}

class _SegRow extends StatelessWidget {
  const _SegRow({required this.label, required this.options, required this.value, required this.onChanged, this.desc});
  final String label;
  final String? desc;
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => _Row(
        label: label,
        desc: desc,
        control: KSegmented<String>(
          label: label,
          height: 28,
          value: options.contains(value) ? value : options.first,
          onChanged: onChanged,
          items: [for (final o in options) (o, o, null)],
        ),
      );
}

class _KbdRow extends StatelessWidget {
  const _KbdRow(this.label, this.keys);
  final String label;
  final List<String> keys;

  @override
  Widget build(BuildContext context) => _Row(
        label: label,
        control: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final k in keys) Padding(padding: const EdgeInsets.only(left: 4), child: Kbd(k)),
        ]),
      );
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({required this.value, required this.options, required this.onChanged});
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final style = sans(12.5, color: c.text);
    return Container(
      width: 220,
      height: 30,
      padding: const EdgeInsets.only(left: 10, right: 6),
      decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(9), border: Border.all(color: c.chipBorder)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          focusColor: Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          dropdownColor: Color.alphaBlend(c.pop, c.isDark ? const Color(0xFF181A24) : const Color(0xFFF7F8FB)),
          icon: Icon(Icons.unfold_more_rounded, size: 16, color: c.text3),
          style: style,
          items: [for (final o in options) DropdownMenuItem<String>(value: o, child: Text(o, style: style, overflow: TextOverflow.ellipsis))],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

class _TextSetting extends StatefulWidget {
  const _TextSetting({super.key, required this.value, required this.onChanged, this.mono = false});
  final String value;
  final bool mono;
  final ValueChanged<String> onChanged;

  @override
  State<_TextSetting> createState() => _TextSettingState();
}

class _TextSettingState extends State<_TextSetting> {
  late final _ctrl = TextEditingController(text: widget.value);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final style = widget.mono ? mono(12, color: c.text) : sans(12.5, color: c.text);
    return Container(
      width: 280,
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(color: c.chip, borderRadius: BorderRadius.circular(9), border: Border.all(color: c.chipBorder)),
      child: TextField(
        controller: _ctrl,
        onChanged: widget.onChanged,
        style: style,
        cursorColor: c.acc,
        decoration: const InputDecoration.collapsed(hintText: ''),
      ),
    );
  }
}

class _PercentSlider extends StatelessWidget {
  const _PercentSlider({required this.value, required this.onChanged});
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: 200,
        child: SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: c.accFill,
            inactiveTrackColor: c.tile,
            thumbColor: const Color(0xFFFFFFFF),
            overlayColor: c.accSoft,
          ),
          child: Slider(
            value: value,
            min: 0.25,
            max: 0.9,
            onChanged: onChanged,
            semanticFormatterCallback: (v) => 'Translucency ${(v * 100).round()} percent',
          ),
        ),
      ),
      SizedBox(width: 40, child: Text('${(value * 100).round()}%', textAlign: TextAlign.right, style: mono(11.5, color: c.text2))),
    ]);
  }
}

/// A whole-number slider with its value and [unit] next to it.
class _StepSlider extends StatelessWidget {
  const _StepSlider({required this.label, required this.value, required this.min, required this.max, required this.unit, required this.onChanged});
  final String label;
  final double value;
  final int min;
  final int max;
  final String unit;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final v = value.round().clamp(min, max);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: 160,
        child: SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            activeTrackColor: c.accFill,
            inactiveTrackColor: c.tile,
            thumbColor: const Color(0xFFFFFFFF),
            overlayColor: c.accSoft,
          ),
          child: Slider(
            value: v.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            onChanged: (x) {
              if (x.round() != v) onChanged(x.round());
            },
            semanticFormatterCallback: (x) => '$label ${x.round()}$unit',
          ),
        ),
      ),
      SizedBox(width: 44, child: Text('$v$unit', textAlign: TextAlign.right, style: mono(11.5, color: c.text2))),
    ]);
  }
}

class _ThemePicker extends StatelessWidget {
  const _ThemePicker({required this.value, required this.onChanged});
  final KumoThemeMode value;
  final ValueChanged<KumoThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    const looks = {
      KumoThemeMode.dark: ('Dark', Color(0xFF1B1D2A), Color(0xFF2A2D40), Color(0xFF0D0F18)),
      KumoThemeMode.light: ('Light', Color(0xFFEEF0F6), Color(0xFFFFFFFF), Color(0xFFDADDE8)),
      KumoThemeMode.hybrid: ('Hybrid', Color(0xFFEEF0F6), Color(0xFFFFFFFF), Color(0xFF191B27)),
    };
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (final m in KumoThemeMode.values)
        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: KPressable(
            onTap: () => onChanged(m),
            semanticLabel: '${looks[m]!.$1} theme',
            selected: m == value,
            builder: (context, hover, focus) {
              final (label, bg, side, term) = looks[m]!;
              final on = m == value;
              return Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 84,
                  height: 54,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10), border: Border.all(color: on ? c.accFill : (hover ? c.text3 : c.chipBorder), width: 2)),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Container(width: 18, decoration: BoxDecoration(color: side, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(width: 4),
                    Expanded(child: Container(decoration: BoxDecoration(color: term, borderRadius: BorderRadius.circular(4)))),
                  ]),
                ),
                const SizedBox(height: 6),
                Text(label, style: sans(11.5, weight: on ? FontWeight.w600 : FontWeight.w500, color: on ? c.text : c.text2)),
              ]);
            },
          ),
        ),
    ]);
  }
}

/// The icons Kumo can show itself with, as they look, and a button to make
/// one from an image of yours.
class _AppIconPicker extends StatefulWidget {
  const _AppIconPicker({required this.state});
  final AppState state;

  @override
  State<_AppIconPicker> createState() => _AppIconPickerState();
}

class _AppIconPickerState extends State<_AppIconPicker> {
  bool _busy = false;
  String? _error;

  Future<void> _choose() async {
    final source = await Pasteboard.chooseFile(extensions: AppIcons.imageTypes, message: 'An image for Kumo’s icon: a square one gets rounded corners');
    if (source == null || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.state.useOwnAppIcon(source);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = ok ? null : 'Kumo couldn’t read that file as an image.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final s = widget.state;
    final own = s.ownAppIcon;
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
      Row(mainAxisSize: MainAxisSize.min, children: [
        for (final icon in AppIcon.values)
          if (icon.preview != null)
            _AppIconTile(icon: icon, image: AssetImage(icon.preview!), selected: icon == s.appIcon, onTap: () => s.appIcon = icon)
          else if (icon == AppIcon.own && own != null)
            _AppIconTile(icon: icon, image: FileImage(File(own)), selected: icon == s.appIcon, onTap: () => s.appIcon = icon),
        if (AppIcons.canMakeOwn)
          Padding(
            padding: const EdgeInsets.only(left: 14, bottom: 22),
            child: KButton(label: _busy ? 'Making it…' : 'Choose image…', height: 28, fontSize: 12, onTap: _busy ? null : _choose),
          ),
      ]),
      if (_error != null) ...[const SizedBox(height: 6), Text(_error!, style: sans(11.5, color: c.err))],
    ]);
  }
}

class _AppIconTile extends StatelessWidget {
  const _AppIconTile({required this.icon, required this.image, required this.selected, required this.onTap});
  final AppIcon icon;
  final ImageProvider image;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(left: 10),
      child: KPressable(
        onTap: onTap,
        semanticLabel: '${icon.label} app icon',
        selected: selected,
        builder: (context, hover, focus) => Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: selected ? c.accFill : (hover ? c.text3 : Colors.transparent), width: 2),
            ),
            // The picture has the room macOS leaves around an icon.
            child: Image(
              image: image,
              width: 60,
              height: 60,
              filterQuality: FilterQuality.medium,
              errorBuilder: (context, error, stack) => SizedBox(width: 60, height: 60, child: Icon(Icons.image_not_supported_outlined, size: 22, color: c.text3)),
            ),
          ),
          const SizedBox(height: 6),
          Text(icon.label, style: sans(11.5, weight: selected ? FontWeight.w600 : FontWeight.w500, color: selected ? c.text : c.text2)),
        ]),
      ),
    );
  }
}

/// Forgets every remembered command, on a second click.
class _ForgetCommands extends StatefulWidget {
  const _ForgetCommands();

  @override
  State<_ForgetCommands> createState() => _ForgetCommandsState();
}

class _ForgetCommandsState extends State<_ForgetCommands> {
  bool _asked = false;
  String? _done;

  Future<void> _forget() async {
    if (!_asked) {
      setState(() => _asked = true);
      return;
    }
    final conn = EngineScope.maybeOf(context)?.current;
    if (conn == null) return;
    try {
      final reply = await conn.terminals.forgetHistory(ForgetHistoryRequest(everything: true));
      if (mounted) setState(() => _done = 'Forgot ${reply.forgotten}');
    } on Object catch (e) {
      if (mounted) setState(() => _done = 'Couldn’t: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final done = _done;
    if (done != null) return Text(done, style: sans(12, color: context.c.text3));
    return KButton(label: _asked ? 'Click again to forget' : 'Forget all', height: 30, fontSize: 12, onTap: _forget);
  }
}
