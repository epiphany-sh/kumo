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
        LogicalKeyboardKey.digit6,
      ];
      for (var i = 0; i < keys.length; i++) {
        final v = KumoView.values[i];
        map[SingleActivator(keys[i], meta: true)] = () => s.view = v;
        map[SingleActivator(keys[i], control: true)] = () => s.view = v;
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
                    if (s.sidebarVisible) ...[const Sidebar(), const SizedBox(width: 10)],
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
