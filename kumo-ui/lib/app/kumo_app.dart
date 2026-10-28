import 'package:flutter/material.dart';

import '../engine/engine_scope.dart';
import '../engine/kumo_engine.dart';
import '../platform/window_effects.dart';
import '../shell/app_shell.dart';
import '../theme/kumo_theme.dart';
import '../theme/palette.dart';
import 'app_state.dart';

class KumoApp extends StatefulWidget {
  const KumoApp({super.key, required this.state, this.engine});

  final AppState state;

  /// The daemon connection. Null in widget tests: terminals are mocks then.
  final KumoEngine? engine;

  @override
  State<KumoApp> createState() => _KumoAppState();
}

class _KumoAppState extends State<KumoApp> {
  @override
  void initState() {
    super.initState();
    widget.state.addListener(_syncWindow);
    _syncWindow();
  }

  @override
  void dispose() {
    widget.state.removeListener(_syncWindow);
    super.dispose();
  }

  void _syncWindow() {
    final dark = widget.state.mode == KumoThemeMode.dark;
    WindowEffects.apply(dark ? Brightness.dark : Brightness.light);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final s = widget.state;
        final base = s.mode == KumoThemeMode.dark ? KumoPalette.dark : KumoPalette.light;
        final palette = base.withTranslucency(s.translucency);
        final terminal = s.mode == KumoThemeMode.hybrid ? KumoPalette.hybridTerminal : palette;
        final app = AppScope(
          state: s,
          child: KumoTheme(
            mode: s.mode,
            palette: palette,
            terminalPalette: terminal,
            child: MaterialApp(
              title: 'Kumo',
              debugShowCheckedModeBanner: false,
              color: Colors.transparent,
              theme: materialThemeFor(palette),
              home: const AppShell(),
            ),
          ),
        );
        final engine = widget.engine;
        return engine == null ? app : EngineScope(engine: engine, child: app);
      },
    );
  }
}
