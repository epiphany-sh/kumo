import 'package:flutter/widgets.dart';

import 'app/app_state.dart';
import 'app/kumo_app.dart';
import 'app/preferences.dart';
import 'data/pipelines_source.dart';
import 'data/profiles_source.dart';
import 'engine/engine_agent_defs.dart';
import 'engine/engine_agents_source.dart';
import 'engine/engine_ai_usage.dart';
import 'engine/engine_pipelines_source.dart';
import 'engine/engine_docs.dart';
import 'engine/engine_profiles.dart';
import 'engine/engine_pull_requests.dart';
import 'engine/engine_tasks_source.dart';
import 'engine/engine_tests_source.dart';
import 'engine/engine_workspace_source.dart';
import 'engine/engine_worktree_changes.dart';
import 'engine/kumo_engine.dart';
import 'platform/new_window.dart';
import 'platform/updates.dart';
import 'platform/window_effects.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Discover or launch kumod while the window comes up; nothing waits on it.
  // This engine is the default workspace's, lists the workspaces and keeps
  // the daemon updated; another workspace gets an engine of its own.
  final primary = KumoEngine()..connection().ignore();
  await WindowEffects.init();
  final prefs = Preferences.load();
  // A window opened for a workspace ("Open in new window") starts on it;
  // otherwise on the default one, then back to the last one used.
  final launched = launchWorkspace;
  final profiles = EngineProfiles(primary, prefs, initial: launched);
  final updates = SparkleUpdates(stopDaemon: primary.stopForUpdate);

  AppState stateFor(KumoEngine engine, {bool owner = false}) {
    final agents = EngineAgentsSource(engine);
    final workspace = EngineWorkspaceSource(engine);
    return AppState(
      demoWallpaper: !WindowEffects.nativeBackdrop,
      prefs: prefs,
      profiles: profiles,
      ownsShared: owner,
      workspace: workspace,
      changesFor: (worktree) => EngineWorktreeChanges(engine, worktree),
      agents: agents,
      agentDefs: EngineAgentDefs(engine, agents, workspace),
      usage: EngineAiUsage(engine, agents),
      tasks: EngineTasksSource(engine),
      pipelinesFor: ({required repo, required worktree, required worktreePath}) =>
          EnginePipelinesSource(engine, worktreePath, provider: CiProvider.ofHost(repo.host), branch: worktree.branch),
      testsFor: (worktree) => EngineTestsSource(engine, worktree),
      ciHosts: EngineCiHostsSource(engine),
      pullRequests: EnginePullRequests(engine),
      docs: EngineDocs(engine),
      updates: updates,
    );
  }

  KumoEngine engineFor(AppProfile p) => p.isDefault ? primary : KumoEngine.scoped(primary, p.id);

  final firstEngine = launched == null ? primary : KumoEngine.scoped(primary, launched);
  final state = stateFor(firstEngine, owner: true);
  runApp(KumoApp(
    state: state,
    engine: firstEngine,
    resumeProfile: launched == null ? prefs.get<String>('profile.current', '') : null,
    openWorkspace: (p) {
      final engine = engineFor(p);
      return (stateFor(engine), engine);
    },
  ));
}
