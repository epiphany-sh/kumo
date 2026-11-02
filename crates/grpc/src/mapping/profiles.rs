use kumo_application::profiles::ProfileView;
use kumo_domain::profiles::{GhAccount, SshKey};
use kumo_proto::v1 as pb;

pub fn profile_to(view: &ProfileView) -> pb::Profile {
    let (p, a) = (&view.profile, &view.activity);
    pb::Profile {
        id: p.id.to_string(),
        name: p.name.clone(),
        color: p.color.clone(),
        position: p.position,
        worktrees_dir: p.worktrees_dir.clone(),
        git_name: p.git_name.clone(),
        git_email: p.git_email.clone(),
        is_default: p.is_default(),
        agents_running: a.agents_running,
        agents_waiting: a.agents_waiting,
        terminals_open: a.terminals_open,
        namespaces: a.namespaces,
        repos: a.repos,
        ssh_key: p.ssh_key.clone(),
        sign_commits: p.sign_commits,
        gh_accounts: p.gh_accounts.iter().map(gh_account_to).collect(),
    }
}

pub fn gh_account_to(account: &GhAccount) -> pb::GhAccount {
    pb::GhAccount {
        host: account.host.clone(),
        login: account.login.clone(),
    }
}

pub fn gh_account_from(account: pb::GhAccount) -> GhAccount {
    GhAccount::new(&account.host, &account.login)
}

pub fn ssh_key_to(key: SshKey) -> pb::SshKey {
    pb::SshKey {
        name: key.name,
        path: key.path,
        fingerprint: key.fingerprint,
        kind: key.kind,
        agent_only: key.agent_only,
    }
}

pub fn profile_list_to(views: &[ProfileView]) -> pb::ProfileList {
    pb::ProfileList {
        profiles: views.iter().map(profile_to).collect(),
    }
}
