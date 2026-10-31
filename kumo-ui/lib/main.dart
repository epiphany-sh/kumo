import 'package:flutter/widgets.dart';

import 'app/app_state.dart';
import 'app/kumo_app.dart';
import 'app/preferences.dart';
import 'data/pipelines_source.dart';
import 'engine/engine_agents_source.dart';
import 'engine/engine_ai_usage.dart';
import 'engine/engine_pipelines_source.dart';
import 'engine/engine_docs.dart';
import 'engine/engine_pull_requests.dart';
import 'engine/engine_tasks_source.dart';
import 'engine/engine_tests_source.dart';
import 'engine/engine_workspace_source.dart';
import 'engine/engine_worktree_changes.dart';
import 'engine/kumo_engine.dart';
import 'platform/updates.dart';
import 'platform/window_effects.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Discover or launch kumod while the window comes up; nothing waits on it.
  final engine = KumoEngine()..connection().ignore();
  await WindowEffects.init();
  final agents = EngineAgentsSource(engine);
  final state = AppState(
    demoWallpaper: !WindowEffects.nativeBackdrop,
    prefs: Preferences.load(),
    workspace: EngineWorkspaceSource(engine),
    changesFor: (worktree) => EngineWorktreeChanges(engine, worktree),
    agents: agents,
    usage: EngineAiUsage(engine, agents),
    tasks: EngineTasksSource(engine),
    pipelinesFor: ({required repo, required worktree, required worktreePath}) =>
        EnginePipelinesSource(engine, worktreePath, provider: CiProvider.ofHost(repo.host), branch: worktree.branch),
    testsFor: (worktree) => EngineTestsSource(engine, worktree),
    ciHosts: EngineCiHostsSource(engine),
    pullRequests: EnginePullRequests(engine),
    docs: EngineDocs(engine),
    updates: SparkleUpdates(stopDaemon: engine.stopForUpdate),
  );
  runApp(KumoApp(state: state, engine: engine));
}
