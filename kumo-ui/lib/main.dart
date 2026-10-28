import 'package:flutter/widgets.dart';

import 'app/app_state.dart';
import 'app/kumo_app.dart';
import 'app/preferences.dart';
import 'engine/engine_workspace_source.dart';
import 'engine/engine_worktree_changes.dart';
import 'engine/kumo_engine.dart';
import 'platform/window_effects.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Discover or launch kumod while the window comes up; nothing waits on it.
  final engine = KumoEngine()..connection().ignore();
  await WindowEffects.init();
  final state = AppState(
    demoWallpaper: !WindowEffects.nativeBackdrop,
    prefs: Preferences.load(),
    workspace: EngineWorkspaceSource(engine),
    changesFor: (worktree) => EngineWorktreeChanges(engine, worktree),
  );
  runApp(KumoApp(state: state, engine: engine));
}
