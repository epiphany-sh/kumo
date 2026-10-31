import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/app_state.dart';
import '../overlays/settings_dialog.dart';
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
      const keys = [
        LogicalKeyboardKey.digit1,
        LogicalKeyboardKey.digit2,
        LogicalKeyboardKey.digit3,
        LogicalKeyboardKey.digit4,
        LogicalKeyboardKey.digit5,
      ];
      final nav = KumoView.nav;
      for (var i = 0; i < keys.length && i < nav.length; i++) {
        final v = nav[i];
        // ⌘1 is Terminal in the side-nav: Home.
        final VoidCallback go = v == KumoView.terminal ? s.showHome : () => s.view = v;
        map[SingleActivator(keys[i], meta: true)] = go;
        map[SingleActivator(keys[i], control: true)] = go;
      }
      for (final mod in [true, false]) {
        map[SingleActivator(LogicalKeyboardKey.keyL, meta: mod, control: !mod, shift: true)] = s.cycleTheme;
        map[SingleActivator(LogicalKeyboardKey.keyN, meta: mod, control: !mod, shift: true)] = s.requestNewWorktree;
        map[SingleActivator(LogicalKeyboardKey.keyS, meta: mod, control: !mod, alt: true)] = s.toggleSidebar;
        map[SingleActivator(LogicalKeyboardKey.keyB, meta: mod, control: !mod, alt: true)] = s.toggleSidePanel;
      }
      // Terminal panes, iTerm-style (forwarded only while the Terminal view
      // is showing): ⌘D split right, ⇧⌘D split down, ⌘W close, ⌘T new.
      map[const SingleActivator(LogicalKeyboardKey.keyD, meta: true)] = () => s.sendTerminalCommand(TerminalCommand.splitRight);
      map[const SingleActivator(LogicalKeyboardKey.keyD, meta: true, shift: true)] = () => s.sendTerminalCommand(TerminalCommand.splitDown);
      map[const SingleActivator(LogicalKeyboardKey.keyW, meta: true)] = () => s.sendTerminalCommand(TerminalCommand.closePane);
      map[const SingleActivator(LogicalKeyboardKey.keyT, meta: true)] = () => s.sendTerminalCommand(TerminalCommand.newTerminal);
      map[const SingleActivator(LogicalKeyboardKey.comma, meta: true)] = () => showSettingsDialog(context);
      map[const SingleActivator(LogicalKeyboardKey.comma, control: true)] = () => showSettingsDialog(context);
      return map;
    }

    return Material(
      type: MaterialType.transparency,
      child: CallbackShortcuts(
        bindings: bindings(),
        child: Focus(
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
