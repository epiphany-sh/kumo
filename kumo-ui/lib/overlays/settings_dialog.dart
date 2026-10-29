import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../theme/kumo_theme.dart';
import '../theme/palette.dart';
import '../widgets/controls.dart';
import '../widgets/glass.dart';
import 'agent_settings.dart';
import 'docs_settings.dart';
import 'host_settings.dart';
import 'task_settings.dart';

enum SettingsTab {
  general('General', Icons.settings_outlined),
  appearance('Appearance', Icons.palette_outlined),
  terminal('Terminal', Icons.terminal_rounded),
  shortcuts('Shortcuts', Icons.keyboard_outlined),
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
      if (page.custom != null) page.custom!,
      for (final sec in page.sections) ...[const SizedBox(height: 16), _Section(title: sec.$1, rows: sec.$2)],
    ];
  }

  // ------------------------------------------------------------ pages

  _Page _page(BuildContext context, AppState s) {
    switch (_tab) {
      case SettingsTab.general:
        return _Page('General', 'How Kumo starts, updates and where it keeps its data.', sections: [
          ('Layout', [
            _SegRow(
              label: 'Side panel position',
              desc: 'Where the Files · Widgets · Source control panel sits in the Terminal view.',
              options: const ['Left', 'Right'],
              value: s.sidePanelRight ? 'Right' : 'Left',
              onChanged: (v) => s.sidePanelRight = v == 'Right',
            ),
            _ToggleRow(label: 'Show the side panel when Kumo opens', desc: 'Hide or show it anytime with ⌥⌘B.', value: s.sidePanelOnLaunch, onChanged: (v) => s.sidePanelOnLaunch = v),
          ]),
          ('Startup', [
            _toggle(s, 'general.login', 'Open Kumo at login', null, false),
            _select(s, 'general.workspace', 'Default workspace', 'Namespace selected when the app opens.', const ['Last used', 'pricing', 'identity'], 'Last used'),
            _toggle(s, 'general.reopen', 'Reopen terminals and agents from last session', 'kumod keeps them running while the app is closed.', true),
          ]),
          ('Updates & privacy', [
            _seg(s, 'general.channel', 'Update channel', null, const ['Stable', 'Beta'], 'Stable'),
            _toggle(s, 'general.autoUpdate', 'Download updates automatically', null, true),
            _toggle(s, 'general.crash', 'Send anonymous crash reports', 'No code, prompts or file contents ever leave your machine this way.', true),
          ]),
        ]);
      case SettingsTab.appearance:
        return _Page('Appearance', 'Liquid Glass themes and translucency.', sections: [
          ('Theme', [
            _Row(label: 'Theme', control: _ThemePicker(value: s.mode, onChanged: (m) => s.mode = m)),
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
        ]);
      case SettingsTab.terminal:
        return _Page('Terminal', 'Shell, font and keyboard behaviour of every terminal pane.', sections: [
          ('Shell', [
            _select(s, 'terminal.shell', 'Shell', 'Login shell for new tabs (⌘T) and splits.', const ['/bin/zsh', '/bin/bash', '/opt/homebrew/bin/fish'], '/bin/zsh'),
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
        ]);
      case SettingsTab.shortcuts:
        return _Page('Shortcuts', 'Keyboard shortcuts across Kumo.', sections: [
          ('Terminal', const [
            _KbdRow('New tab', ['⌘', 'T']),
            _KbdRow('Split right', ['⌘', 'D']),
            _KbdRow('Split down', ['⇧', '⌘', 'D']),
            _KbdRow('Close pane', ['⌘', 'W']),
            _KbdRow('Show / hide side panel', ['⌥', '⌘', 'B']),
          ]),
          ('Workspace', const [
            _KbdRow('Terminal (Home) · Agents · Tasks · Git · Docs', ['⌘', '1…5']),
            _KbdRow('Settings', ['⌘', ',']),
            _KbdRow('New worktree', ['⇧', '⌘', 'N']),
            _KbdRow('Show / hide sidebar', ['⌥', '⌘', 'S']),
            _KbdRow('Cycle theme', ['⇧', '⌘', 'L']),
          ]),
          ('Source control', const [
            _KbdRow('Commit', ['⌘', '↩']),
          ]),
        ]);
      case SettingsTab.ai:
        return _Page(
          'AI agents',
          'Coding agents Kumo can run in your worktrees, with your own sign-in: Kumo never proxies models. Each one runs in its own terminal. Optional: everything else works without them.',
          custom: const AgentSettingsPanel(),
          sections: [
            ('Defaults', [
              _toggle(s, 'ai.ownWorktree', 'Give every agent its own worktree', 'Agents never share a checkout, so they can’t step on each other.', true),
              _toggle(s, 'ai.notify', 'Notify me when an agent needs input', null, true),
            ]),
          ],
        );
      case SettingsTab.tickets:
        return _Page(
          'Tasks',
          'Where your tasks come from. Kumo keeps them on this Mac so Tasks opens instantly, re-reads them in the background and writes status changes back. Start a worktree with an agent from any of them.',
          custom: const TaskSourceSettingsPanel(),
        );
      case SettingsTab.repos:
        return _Page(
          'Repositories',
          'Tokens for the hosts of your repositories, so the Pipelines widget shows their CI. One per host, kept in the macOS Keychain.',
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
          custom: const DocsSourcesPanel(),
        );
    }
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

class _Page {
  _Page(this.heading, this.intro, {this.sections = const [], this.custom});
  final String heading;
  final String intro;
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
