use kumo_domain::workspace::{GitHost, Remote, RepoState, WorkspaceSnapshot, Worktree};
use kumo_proto::v1 as pb;

pub fn snapshot_to(snapshot: &WorkspaceSnapshot) -> pb::WorkspaceSnapshot {
    pb::WorkspaceSnapshot {
        version: snapshot.version,
        namespaces: snapshot
            .namespaces
            .iter()
            .map(|n| pb::Namespace {
                id: n.id.to_string(),
                name: n.name.clone(),
                repo_paths: n.repos.iter().map(|p| p.display().to_string()).collect(),
                collapsed: n.collapsed,
            })
            .collect(),
        repositories: snapshot.repos.iter().map(repository_to).collect(),
    }
}

fn repository_to(state: &RepoState) -> pb::Repository {
    let (host, full_name, remote_url) = remote_fields(state.repo.remote.as_ref());
    pb::Repository {
        path: state.repo.path.display().to_string(),
        name: state.repo.name.clone(),
        host: host.into(),
        full_name,
        remote_url,
        worktrees: state.worktrees.iter().map(worktree_to).collect(),
        error: state.error.clone().unwrap_or_default(),
    }
}

pub fn worktree_to(worktree: &Worktree) -> pb::Worktree {
    pb::Worktree {
        path: worktree.path.display().to_string(),
        branch: worktree.branch.clone().unwrap_or_default(),
        head: worktree.head.clone(),
        is_main: worktree.is_main,
        locked: worktree.locked,
        status: Some(pb::WorktreeStatus {
            changed_files: worktree.status.changed_files,
            ahead: worktree.status.ahead,
            behind: worktree.status.behind,
            upstream: worktree.status.upstream.clone().unwrap_or_default(),
        }),
    }
}

pub fn candidate_to(state: &RepoState) -> pb::RepoCandidate {
    let (host, full_name, _) = remote_fields(state.repo.remote.as_ref());
    pb::RepoCandidate {
        path: state.repo.path.display().to_string(),
        name: state.repo.name.clone(),
        host: host.into(),
        full_name,
        worktree_count: u32::try_from(state.worktrees.len()).unwrap_or(u32::MAX),
    }
}

fn remote_fields(remote: Option<&Remote>) -> (pb::GitHost, String, String) {
    match remote {
        None => (pb::GitHost::Local, String::new(), String::new()),
        Some(remote) => {
            let host = match remote.host {
                GitHost::GitHub => pb::GitHost::Github,
                GitHost::GitLab => pb::GitHost::Gitlab,
                GitHost::Bitbucket => pb::GitHost::Bitbucket,
                GitHost::Other => pb::GitHost::Other,
            };
            (
                host,
                remote.full_name.clone().unwrap_or_default(),
                remote.url.clone(),
            )
        }
    }
}
