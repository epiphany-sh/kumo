import 'package:flutter/material.dart';

import '../data/profiles_source.dart';
import '../engine/engine_scope.dart';
import '../engine/kumo_engine.dart';
import '../platform/window_effects.dart';
import '../shell/app_shell.dart';
import '../shell/update_snackbar.dart';
import '../theme/kumo_theme.dart';
import '../theme/palette.dart';
import 'app_state.dart';

/// What a window needs to show another workspace: its own state and engine
/// (calls carry that workspace's `kumo-profile`, so nothing mixes).
typedef WorkspaceOpener = (AppState, KumoEngine?) Function(AppProfile profile);

class KumoApp extends StatefulWidget {
  const KumoApp({super.key, required this.state, this.engine, this.openWorkspace, this.resumeProfile});

  /// The state of the workspace the window opens on.
  final AppState state;

  /// The daemon connection. Null in widget tests: terminals are mocks then.
  final KumoEngine? engine;

  /// Makes another workspace's state. Null: one state switches in place.
  final WorkspaceOpener? openWorkspace;

  /// The workspace to go back to once the list arrives (the last one used).
  final String? resumeProfile;

  @override
  State<KumoApp> createState() => _KumoAppState();
}

class _KumoAppState extends State<KumoApp> {
  late AppState _state = widget.state;
  late KumoEngine? _engine = widget.engine;

  /// Each workspace's state stays while the window lives: back in one, its
  /// tabs and selection are as they were, and its agents never stopped.
  final _open = <String, (AppState, KumoEngine?)>{};
  bool _resumed = false;

  ProfilesSource get _profiles => widget.state.profiles;

  @override
  void initState() {
    super.initState();
    _open[_profiles.currentId] = (_state, _engine);
    _attach(_state);
    _profiles.addListener(_onProfiles);
    _syncWindow();
    _onProfiles();
  }

  @override
  void dispose() {
    _profiles.removeListener(_onProfiles);
    _state.removeListener(_syncWindow);
    super.dispose();
  }

  void _attach(AppState s) {
    s.addListener(_syncWindow);
    if (widget.openWorkspace != null) s.profileOpener = _show;
  }

  /// Once the daemon's list is in: back to the last workspace, and the
  /// states of deleted ones go.
  void _onProfiles() {
    final all = _profiles.profiles;
    final want = widget.resumeProfile;
    if (!_resumed && want != null && want.isNotEmpty && _profiles.canManage) {
      _resumed = true;
      if (want != _profiles.currentId && all.any((p) => p.id == want)) _state.switchProfile(want, offerUndo: false);
    }
    for (final id in [..._open.keys]) {
      if (all.any((p) => p.id == id) || identical(_open[id]!.$1, _state)) continue;
      final (gone, engine) = _open.remove(id)!;
      if (!identical(gone, widget.state)) {
        gone.dispose();
        if (!identical(engine, widget.engine)) engine?.dispose();
      }
    }
  }

  Future<void> _show(String id, AppProfile? announceFrom) async {
    final p = _profiles.profiles.where((x) => x.id == id).firstOrNull;
    final opener = widget.openWorkspace;
    if (p == null || opener == null || !mounted) return;
    final next = _open[id] ??= opener(p);
    if (identical(next.$1, _state)) return;
    next.$1.adoptLook(_state);
    _state.removeListener(_syncWindow);
    setState(() {
      _state = next.$1;
      _engine = next.$2;
    });
    _attach(_state);
    _syncWindow();
    if (announceFrom != null) _state.announceSwitch(announceFrom);
  }

  void _syncWindow() {
    final dark = _state.mode == KumoThemeMode.dark;
    WindowEffects.apply(dark ? Brightness.dark : Brightness.light);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        final s = _state;
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
              // The snackbar inside the navigator: its tooltips need an overlay.
              // Keyed by workspace: another one gets fresh views (its own
              // terminals re-attach), while each keeps its own state.
              home: Stack(
                key: ObjectKey(s),
                fit: StackFit.expand,
                children: const [AppShell(), UpdateSnackbar()],
              ),
            ),
          ),
        );
        final engine = _engine;
        return engine == null ? app : EngineScope(engine: engine, child: app);
      },
    );
  }
}
