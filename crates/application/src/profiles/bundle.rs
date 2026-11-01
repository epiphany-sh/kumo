use std::path::PathBuf;
use std::sync::Arc;

use futures::future::BoxFuture;
use kumo_domain::agents::AgentState;
use kumo_domain::profiles::{Profile, ProfileActivity, ProfileError};
use kumo_domain::workspace::WorktreeLocation;

use super::ProfileBundle;
use crate::agents::AgentService;
use crate::changes::ChangesService;
use crate::docs::DocsService;
use crate::pipelines::PipelinesService;
use crate::pulls::PullRequestService;
use crate::tasks::TaskService;
use crate::terminal::TerminalService;
use crate::test_runs::TestService;
use crate::workspace::WorkspaceService;

/// Every per-profile use case, over that profile's stores.
#[derive(Debug, Clone)]
pub struct ProfileServices {
    /// The user's home, for `~/` in the worktrees folder.
    pub home: PathBuf,
    pub workspace: Arc<WorkspaceService>,
    pub changes: Arc<ChangesService>,
    pub agents: Arc<AgentService>,
    pub tasks: Arc<TaskService>,
    pub pipelines: Arc<PipelinesService>,
    pub pulls: Arc<PullRequestService>,
    pub docs: Arc<DocsService>,
    pub tests: Arc<TestService>,
    /// The daemon's terminals, scoped to this profile.
    pub terminals: Arc<TerminalService>,
}

impl ProfileBundle for ProfileServices {
    fn activity(&self) -> ProfileActivity {
        let mut activity = ProfileActivity::default();
        for session in self.agents.sessions() {
            match session.state {
                AgentState::Working => activity.agents_running += 1,
                AgentState::NeedsInput => activity.agents_waiting += 1,
                AgentState::Exited(_) => {}
            }
        }
        let snapshot = self.workspace.watch().borrow().clone();
        activity.namespaces = count(snapshot.namespaces.len());
        activity.repos = count(snapshot.repos.len());
        activity.terminals_open = count(self.terminals.running());
        activity
    }

    fn configure(&self, profile: &Profile) {
        match WorktreeLocation::new(&self.home).with_root(&profile.worktrees_dir) {
            Ok(location) => self.workspace.set_location(location),
            Err(error) => tracing::warn!(
                profile = %profile.id,
                %error,
                "worktrees folder ignored"
            ),
        }
    }

    fn close(&self) -> BoxFuture<'_, ()> {
        Box::pin(async move {
            for session in self.agents.sessions() {
                if !matches!(session.state, AgentState::Exited(_)) {
                    let _ = self.agents.stop(&session.id);
                }
            }
            self.terminals.close_all();
        })
    }

    fn copy_agents_from<'a>(&'a self, source: &'a Self) -> BoxFuture<'a, Result<(), ProfileError>> {
        Box::pin(async move {
            self.agents
                .copy_providers_from(&source.agents)
                .await
                .map_err(|e| ProfileError::Storage(e.to_string()))
        })
    }
}

fn count(n: usize) -> u32 {
    u32::try_from(n).unwrap_or(u32::MAX)
}
