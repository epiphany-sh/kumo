//! Keeps a profile's [`ProfileEnv`] up to date: its git identity, SSH key,
//! and which of its hosts git reaches with the profile's token.

use std::collections::BTreeSet;
use std::path::PathBuf;
use std::sync::Arc;

use kumo_domain::pipelines::{CiHost, CiProvider};
use kumo_domain::profiles::{GitSetup, Profile, ProfileEnv};
use kumo_domain::workspace::WorkspaceSnapshot;
use tokio::sync::watch;

use crate::pipelines::PipelinesService;

/// The profile's process environment, recomputed when the profile, the
/// hosts of its repositories or their credentials change.
#[derive(Debug)]
pub struct GitEnvironment {
    env: ProfileEnv,
    profile: watch::Sender<Profile>,
}

/// What it reads to compute the environment.
struct Sources {
    env: ProfileEnv,
    home: PathBuf,
    /// The credential helper command; empty: none (git asks as usual).
    helper: String,
    pipelines: Arc<PipelinesService>,
}

impl GitEnvironment {
    /// Computes the environment of `profile` into `env` once, then keeps
    /// it current until this is dropped.
    pub async fn start(
        env: ProfileEnv,
        profile: Profile,
        home: PathBuf,
        helper: String,
        workspace: watch::Receiver<Arc<WorkspaceSnapshot>>,
        pipelines: Arc<PipelinesService>,
    ) -> Arc<Self> {
        let sources = Sources {
            env: env.clone(),
            home,
            helper,
            pipelines,
        };
        let hosts = hosts_of(&workspace.borrow());
        sources.compute(&profile, &hosts).await;
        let (profile_tx, profile_rx) = watch::channel(profile);
        tokio::spawn(sources.keep_current(profile_rx, workspace, hosts));
        Arc::new(Self {
            env,
            profile: profile_tx,
        })
    }

    /// What its git, terminals and agents get.
    pub fn env(&self) -> ProfileEnv {
        self.env.clone()
    }

    /// The profile changed (identity, key, accounts).
    pub fn configure(&self, profile: &Profile) {
        self.profile.send_replace(profile.clone());
    }
}

impl Sources {
    async fn keep_current(
        self,
        mut profile: watch::Receiver<Profile>,
        mut workspace: watch::Receiver<Arc<WorkspaceSnapshot>>,
        mut hosts: Vec<CiHost>,
    ) {
        let mut credentials = self.pipelines.credentials_changed();
        loop {
            tokio::select! {
                changed = profile.changed() => if changed.is_err() { return },
                changed = workspace.changed() => {
                    if changed.is_err() {
                        return;
                    }
                    // Most snapshots only change git status.
                    let now = hosts_of(&workspace.borrow_and_update());
                    if now == hosts {
                        continue;
                    }
                    hosts = now;
                }
                changed = credentials.changed() => if changed.is_err() { return },
            }
            let current = profile.borrow_and_update().clone();
            self.compute(&current, &hosts).await;
        }
    }

    async fn compute(&self, profile: &Profile, hosts: &[CiHost]) {
        self.pipelines.use_accounts(&profile.gh_accounts);
        let mut setup = GitSetup::of(profile, &self.home);
        setup.helper.clone_from(&self.helper);
        let mut credential_hosts = BTreeSet::new();
        for host in hosts {
            let account = host.provider == CiProvider::GitHubActions
                && profile.gh_account(&host.host).is_some();
            // A token pasted in the default profile served pipelines only
            // before profiles (read scopes): its git stays as it was.
            let saved = !profile.is_default() && self.pipelines.has_saved_token(&host.host).await;
            if account || saved {
                credential_hosts.insert(host.host.clone());
            }
            if account && let Some(token) = self.pipelines.fallback_token(host).await {
                setup.gh_tokens.push((host.host.clone(), token));
            }
        }
        setup.credential_hosts = credential_hosts;
        tracing::debug!(profile = %profile.id, ?setup, "process environment");
        self.env.set(setup);
    }
}

/// The hosts of the workspace's remotes, sorted.
fn hosts_of(snapshot: &WorkspaceSnapshot) -> Vec<CiHost> {
    let mut hosts: Vec<CiHost> = snapshot
        .repos
        .iter()
        .filter_map(|r| CiHost::for_remote(r.repo.remote.as_ref()?))
        .collect();
    hosts.sort_by(|a, b| a.host.cmp(&b.host));
    hosts.dedup_by(|a, b| a.host == b.host);
    hosts
}
