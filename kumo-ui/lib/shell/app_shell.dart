import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../editor/comment.dart';
import '../editor/quick_open.dart';
import '../overlays/global_search.dart';
import '../overlays/settings_dialog.dart';
import '../platform/os/host_os.dart';
import '../platform/os/key_combo.dart';
import '../platform/window_effects.dart';
import '../theme/kumo_theme.dart';
import '../views/agents_screen.dart';
import '../views/docs_screen.dart';
import '../views/files_screen.dart';
import '../views/git_screen.dart';
import '../views/tasks_screen.dart';
import '../views/terminal_screen.dart';
import '../widgets/glass.dart';
import 'sidebar.dart';

/// Window layout: native vibrancy (or demo wallpaper) → window tint →
/// sidebar + current screen. Screens live in an IndexedStack so switching
/// views is instant and terminals keep their state.
class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;

    Map<ShortcutActivator, VoidCallback> bindings() {
      final map = <ShortcutActivator, VoidCallback>{};
      // App-wide keys answer both ⌘ and Ctrl (KeyCombo.activators).
      void bind(KeyCombo combo, VoidCallback action) {
        for (final a in combo.activators) {
          map[a] = action;
        }
      }

      final nav = KumoView.nav;
      for (var i = 0; i < 5 && i < nav.length; i++) {
        final v = nav[i];
        // ⌘1 is Terminal in the side-nav: Home.
        bind(AppKeys.view(i), v == KumoView.terminal ? s.showHome : () => s.view = v);
      }
      // ⌃⌘1…9 (⌃⌥ off macOS): the workspaces, in switcher order.
      for (var n = 1; n <= 9; n++) {
        bind(AppKeys.workspace(n), () => s.switchToProfileAt(n));
      }
      bind(AppKeys.cycleTheme, s.cycleTheme);
      bind(AppKeys.newWorktree, s.requestNewWorktree);
      bind(AppKeys.toggleSidebar, s.toggleSidebar);
      bind(AppKeys.toggleSidePanel, s.toggleSidePanel);
      // Terminal panes, iTerm-style (forwarded only while the Terminal view
      // is showing): ⌘D split right, ⇧⌘D split down, ⌘W close, ⌘T new
      // (Ctrl+Shift+D / E / W / T off macOS, see HostOs.paneShortcut). In
      // the full editor ⌘W closes its file instead.
      void close() => s.view == KumoView.files ? s.sendFileCommand(FileCommand.close) : s.sendTerminalCommand(TerminalCommand.closePane);
      map[hostOs.paneShortcut(PaneShortcut.splitRight)] = () => s.sendTerminalCommand(TerminalCommand.splitRight);
      map[hostOs.paneShortcut(PaneShortcut.splitDown)] = () => s.sendTerminalCommand(TerminalCommand.splitDown);
      map[hostOs.paneShortcut(PaneShortcut.closePane)] = close;
      map[hostOs.paneShortcut(PaneShortcut.newTab)] = () => s.sendTerminalCommand(TerminalCommand.newTerminal);
      bind(AppKeys.settings, () => showSettingsDialog(context));
      bind(AppKeys.search, () => showGlobalSearch(context, s));

      // The editor's keys: ⌘ on macOS, Ctrl elsewhere (AppKeys). Off macOS
      // they only exist while a file shows, so a terminal keeps Ctrl+F,
      // Ctrl+P, Ctrl+W (its shell's).
      final mac = hostOs.commandKey;
      final fileShows = s.view == KumoView.files || (s.view == KumoView.terminal && ((s.activeContext == ContextTab.files && s.contextFile != null) || s.activeFile != null));
      VoidCallback file(FileCommand command) => () => s.sendFileCommand(command);
      if (mac || s.view == KumoView.files || s.activeContext == ContextTab.files) {
        // ⌘P from anywhere: the Files tab (or the full editor) with the file.
        map[AppKeys.quickOpen.activator] = () => goToFile(context, s);
      }
      if (fileShows) {
        if (!mac) map[AppKeys.closeFile.activator] = close;
        map[AppKeys.save.activator] = file(FileCommand.save);
        map[AppKeys.find.activator] = file(FileCommand.find);
        map[AppKeys.replace.activator] = file(FileCommand.replace);
        map[AppKeys.findNext.activator] = file(FileCommand.findNext);
        map[AppKeys.findPrevious.activator] = file(FileCommand.findPrevious);
        map[AppKeys.togglePreview.activator] = file(FileCommand.togglePreview);
        map[CommentKeyActivator(meta: mac)] = file(FileCommand.toggleComment);
        map[AppKeys.nextTab.activator] = file(FileCommand.nextTab);
        map[AppKeys.previousTab.activator] = file(FileCommand.previousTab);
        map[const SingleActivator(LogicalKeyboardKey.tab, control: true)] = file(FileCommand.nextTab);
        map[const SingleActivator(LogicalKeyboardKey.tab, control: true, shift: true)] = file(FileCommand.previousTab);
      }
      return map;
    }

    return Material(
      type: MaterialType.transparency,
      child: CallbackShortcuts(
        bindings: bindings(),
        // A scope, not a plain Focus: when the focused widget goes away or
        // lets go (a text field unfocuses on a click elsewhere), the focus
        // falls back here, under these shortcuts. On the route's scope,
        // above them, every one of them stopped working.
        child: FocusScope(
          autofocus: true,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (s.demoWallpaper || !WindowEffects.nativeBackdrop) DemoWallpaper(palette: c),
              ColoredBox(color: c.window),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (s.sidebarVisible) ...[const Sidebar(), const SidebarResizer()],
                    Expanded(
                      child: IndexedStack(
                        index: s.view.index,
                        sizing: StackFit.expand,
                        children: const [
                          TerminalScreen(),
                          FilesScreen(),
                          AgentsScreen(),
                          TasksScreen(),
                          GitScreen(),
                          DocsScreen(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The 10 px gap right of the sidebar, which drags its width (220–420 px).
/// A grip shows on hover, focus and while dragging; double-click resets it;
/// with the keyboard, ← → change it (⇧ for bigger steps).
class SidebarResizer extends StatefulWidget {
  const SidebarResizer({super.key});

  @override
  State<SidebarResizer> createState() => _SidebarResizerState();
}

class _SidebarResizerState extends State<SidebarResizer> {
  bool _hover = false;
  bool _focus = false;
  bool _dragging = false;
  double _startWidth = 0;
  double _startX = 0;

  void _by(AppState s, double dx) {
    s.sidebarWidth = s.sidebarWidth + dx;
    s.saveSidebarWidth();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final c = context.c;
    final on = _hover || _focus || _dragging;
    final w = s.sidebarWidth.round();
    return Semantics(
      label: 'Resize sidebar',
      value: '$w pixels',
      increasedValue: '${(w + 16).clamp(220, 420)} pixels',
      decreasedValue: '${(w - 16).clamp(220, 420)} pixels',
      onIncrease: () => _by(s, 16),
      onDecrease: () => _by(s, -16),
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.resizeColumn,
        onShowHoverHighlight: (v) => setState(() => _hover = v),
        onShowFocusHighlight: (v) => setState(() => _focus = v),
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.arrowLeft): _Resize(-16),
          SingleActivator(LogicalKeyboardKey.arrowRight): _Resize(16),
          SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true): _Resize(-40),
          SingleActivator(LogicalKeyboardKey.arrowRight, shift: true): _Resize(40),
        },
        actions: {
          _Resize: CallbackAction<_Resize>(onInvoke: (i) {
            _by(s, i.dx);
            return null;
          }),
        },
        child: Tooltip(
          message: 'Drag to resize · double-click to reset',
          waitDuration: const Duration(milliseconds: 600),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            // From where the drag started, so the edge stays under the
            // pointer even after hitting a limit.
            onHorizontalDragStart: (d) => setState(() {
              _dragging = true;
              _startWidth = s.sidebarWidth;
              _startX = d.globalPosition.dx;
            }),
            onHorizontalDragUpdate: (d) => s.sidebarWidth = _startWidth + d.globalPosition.dx - _startX,
            onHorizontalDragEnd: (_) {
              setState(() => _dragging = false);
              s.saveSidebarWidth();
            },
            onHorizontalDragCancel: () => setState(() => _dragging = false),
            onDoubleTap: () {
              s.sidebarWidth = AppState.defaultSidebarWidth;
              s.saveSidebarWidth();
            },
            child: SizedBox(
              width: 10,
              child: Center(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 150),
                  opacity: on ? 1 : 0,
                  child: Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(color: _dragging ? c.acc : c.text3, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Resize extends Intent {
  const _Resize(this.dx);
  final double dx;
}
